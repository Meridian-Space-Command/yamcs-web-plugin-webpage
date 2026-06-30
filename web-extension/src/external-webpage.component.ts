import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import {
  NavGroup,
  NavItem,
  User,
  YaInstanceToolbar,
  YamcsWebExtension,
} from '@yamcs/webapp-sdk';

// Keep in sync with the plugin artifactId / route id / config key.
const TAG = 'external-webpage';

interface PageConfig {
  label: string;
  url: string;
  privilege?: string;
  group?: NavGroup;
  icon?: string;
  order?: number;
}

interface ExtensionConfig {
  // Current format: a list of pages.
  pages?: PageConfig[];
  // Legacy single-page format (top-level keys) — still accepted.
  label?: string;
  url?: string;
  privilege?: string;
  group?: NavGroup;
  icon?: string;
  order?: number;
}

interface ResolvedPage extends PageConfig {
  key: string; // stable URL segment, used as the route subroute
}

// Guard so nav items are registered exactly once, even if the element is
// instantiated multiple times over the app's lifetime.
let navItemsRegistered = false;

/**
 * yamcs-web extension that embeds one or more external webpages. Each configured page
 * becomes a sidebar item; clicking it routes to /<instance>/ext/external-webpage/<key>
 * and renders the real `ya-instance-toolbar` (page label + live mission time) above an
 * iframe of that page's URL.
 *
 * The same element is used by yamcs-web both as a hidden startup initializer (no
 * `subroute` -> registers all sidebar items) and as the routed page (`subroute` is the
 * page key -> renders that page). Services for the toolbar come from the SdkBridge, which
 * the {@link YamcsWebExtension} base populates from the main application.
 */
@Component({
  selector: 'ext-external-webpage',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [YaInstanceToolbar],
  template: `
    @if (showPage()) {
      <div class="container">
        <ya-instance-toolbar [label]="label()" />
        <iframe [src]="safeUrl()" referrerpolicy="no-referrer"></iframe>
      </div>
    }
  `,
  styles: `
    :host {
      position: absolute;
      inset: 0;
      display: block;
    }
    .container {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
    }
    iframe {
      flex: 1 1 auto;
      width: 100%;
      border: 0;
      display: block;
    }
  `,
})
export class ExternalWebpageComponent extends YamcsWebExtension {
  private sanitizer = inject(DomSanitizer);

  showPage = signal(false);
  label = signal('');
  safeUrl = signal<SafeResourceUrl | null>(null);

  onExtensionInit(): void {
    const pages = this.resolvePages();
    if (pages.length === 0) {
      console.error(
        `[${TAG}] No pages configured. Define a 'pages' list (or a top-level label/url) in etc/external-webpage.yaml.`,
      );
      return;
    }

    if (this.subroute === undefined) {
      this.registerNavItems(pages);
    } else {
      // Routed page: pick the page matching the subroute key (fall back to the first).
      const page = pages.find((p) => p.key === this.subroute) ?? pages[0];
      this.label.set(page.label);
      this.safeUrl.set(this.sanitizer.bypassSecurityTrustResourceUrl(page.url));
      this.showPage.set(true);
    }
  }

  /** Normalises the config (list or legacy single-page) into a list with stable keys. */
  private resolvePages(): ResolvedPage[] {
    const cfg = this.configService.getExtraConfig(TAG) as ExtensionConfig | undefined;
    if (!cfg) {
      return [];
    }

    let raw: PageConfig[];
    if (Array.isArray(cfg.pages)) {
      raw = cfg.pages;
    } else if (cfg.url) {
      // Legacy single-page format (top-level keys).
      raw = [
        {
          label: cfg.label ?? cfg.url,
          url: cfg.url,
          privilege: cfg.privilege,
          group: cfg.group,
          icon: cfg.icon,
          order: cfg.order,
        },
      ];
    } else {
      raw = [];
    }
    raw = raw.filter((p) => p && p.url);

    const usedKeys = new Set<string>();
    return raw.map((p, index) => {
      let key = this.slug(p.label) || `page-${index}`;
      if (usedKeys.has(key)) {
        key = `${key}-${index}`;
      }
      usedKeys.add(key);
      return { ...p, key };
    });
  }

  private registerNavItems(pages: ResolvedPage[]) {
    if (navItemsRegistered) {
      return;
    }
    navItemsRegistered = true;

    pages.forEach((page, index) => {
      const item: NavItem = {
        path: `ext/${TAG}/${page.key}`,
        label: page.label,
        icon: page.icon || 'public',
        order: page.order ?? index,
      };

      // Permission gate: only users with this system privilege (or superusers) see the item.
      // A blank privilege or '*' means "no gate" -> visible to all users.
      const privilege = (page.privilege || '').trim();
      if (privilege !== '' && privilege !== '*') {
        item.condition = (user: User) => user.hasSystemPrivilege(privilege);
      }

      // The 'archive' group renders extension items as standalone entries at the bottom
      // of the instance sidebar with a correct '/ext/<id>/<key>' link.
      this.extensionService.addNavItem(page.group || 'archive', item);
    });
  }

  /** lowercase, hyphenated slug usable as a single URL segment. */
  private slug(value: string): string {
    return (value || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }
}

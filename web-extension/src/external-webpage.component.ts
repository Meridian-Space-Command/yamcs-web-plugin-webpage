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
  privilege: string;
  group?: NavGroup;
  icon?: string;
  order?: number;
}

// Guard so the nav item is registered exactly once, even if the element is
// instantiated multiple times over the app's lifetime.
let navItemRegistered = false;

/**
 * yamcs-web extension page that embeds an external webpage, using the real
 * `ya-instance-toolbar` for the header (label on the left, live mission time on the
 * right). Services for the toolbar are provided through the SdkBridge, which the
 * {@link YamcsWebExtension} base populates from the main application when it injects
 * `extensionService` onto this element.
 *
 * The same element is used twice by yamcs-web (see main.ts):
 *  - as a hidden startup initializer (no `subroute`) -> registers the sidebar nav item;
 *  - as the routed page (`subroute` is set) -> renders the toolbar + iframe.
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
    const cfg = this.configService.getExtraConfig(TAG) as PageConfig | undefined;
    if (!cfg || !cfg.url) {
      console.error(
        `[${TAG}] No extension configuration found. Is the plugin configured in etc/external-webpage.yaml?`,
      );
      return;
    }

    if (this.subroute === undefined) {
      this.registerNavItem(cfg);
    } else {
      this.label.set(cfg.label);
      this.safeUrl.set(this.sanitizer.bypassSecurityTrustResourceUrl(cfg.url));
      this.showPage.set(true);
    }
  }

  private registerNavItem(cfg: PageConfig) {
    if (navItemRegistered) {
      return;
    }
    navItemRegistered = true;

    const item: NavItem = {
      path: `ext/${TAG}`,
      label: cfg.label,
      icon: cfg.icon || 'public',
      order: cfg.order ?? 0,
      // Permission gate: only users with this system privilege (or superusers) see the item.
      condition: (user: User) => user.hasSystemPrivilege(cfg.privilege),
    };

    // The 'archive' group renders extension items as standalone entries at the bottom
    // of the instance sidebar with a correct '/ext/<id>' link.
    this.extensionService.addNavItem(cfg.group || 'archive', item);
  }
}

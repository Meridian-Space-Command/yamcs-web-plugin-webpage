import type { ExtensionService, NavGroup, NavItem, User } from './yamcs-sdk.js';

/**
 * Custom element implementing a yamcs-web extension that embeds an external webpage.
 *
 * yamcs-web uses the SAME custom element for two purposes, distinguished by whether
 * `subroute` is set before `extensionService`:
 *
 *   - Startup initializer: AppComponent instantiates `<external-webpage>` in a hidden
 *     container and sets only `.extensionService`. We use this to register the sidebar
 *     nav item (once).
 *   - Routed page: ExtensionComponent instantiates `<external-webpage>` for the route
 *     `/<instance>/ext/external-webpage`, setting `.subroute` first and then
 *     `.extensionService`. We use this to render the embedded webpage.
 *
 * The displayed name and the URL are NOT hard-coded here: they are read at runtime from
 * the plugin configuration (etc/external-webpage.yaml -> label / url).
 *
 * The tag name MUST equal the Yamcs plugin name (artifactId `external-webpage`).
 */

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

class ExternalWebpageElement extends HTMLElement {
  private subrouteValue: string | undefined;

  set subroute(value: string) {
    this.subrouteValue = value;
  }

  set extensionService(service: ExtensionService) {
    const cfg = service.configService.getExtraConfig(TAG) as PageConfig | undefined;
    if (!cfg || !cfg.url) {
      console.error(
        `[${TAG}] No extension configuration found. Is the plugin configured in etc/external-webpage.yaml?`,
      );
      return;
    }

    if (this.subrouteValue === undefined) {
      this.registerNavItem(service, cfg);
    } else {
      this.renderPage(cfg);
    }
  }

  private registerNavItem(service: ExtensionService, cfg: PageConfig) {
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
    // of the instance sidebar with a correct '/ext/<id>' link; other groups would
    // produce a broken '/<group>/ext/<id>' link.
    service.addNavItem(cfg.group || 'archive', item);
  }

  private renderPage(cfg: PageConfig) {
    // Fill the main content area. Absolute positioning makes the iframe fill the
    // nearest positioned ancestor (the page content container) regardless of the
    // host element's intrinsic height.
    this.style.display = 'block';
    this.style.position = 'absolute';
    this.style.inset = '0';

    const iframe = document.createElement('iframe');
    iframe.src = cfg.url;
    iframe.title = cfg.label;
    iframe.setAttribute('referrerpolicy', 'no-referrer');
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = '0';
    iframe.style.display = 'block';

    this.replaceChildren(iframe);
  }
}

if (!customElements.get(TAG)) {
  customElements.define(TAG, ExternalWebpageElement);
}

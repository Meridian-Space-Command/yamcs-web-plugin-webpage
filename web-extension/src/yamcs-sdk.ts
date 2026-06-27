/**
 * Minimal, hand-written type surface for the parts of @yamcs/webapp-sdk that this
 * extension touches. We deliberately avoid depending on the published SDK package so
 * the build has no runtime dependencies and is not coupled to a specific Angular /
 * yamcs-web version. These types mirror the public contract verified against yamcs-web
 * (ExtensionService, NavItem, User, ConfigService).
 */

export type NavGroup =
  | 'telemetry'
  | 'commanding'
  | 'procedures'
  | 'archive'
  | 'mdb';

export interface User {
  hasSystemPrivilege(privilege: string): boolean;
}

export interface NavItem {
  path: string;
  label: string;
  icon?: string;
  order?: number;
  activeWhen?: string;
  condition?: (user: User) => boolean;
}

export interface ConfigService {
  getExtraConfig(key: string): any;
}

/**
 * The main webapp's ExtensionService instance, injected onto the custom element by
 * yamcs-web (both for the hidden startup initializer and for the routed page).
 */
export interface ExtensionService {
  readonly configService: ConfigService;
  addNavItem(group: NavGroup, item: NavItem): void;
}

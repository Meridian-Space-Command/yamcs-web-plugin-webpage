import { createCustomElement } from '@angular/elements';
import { createApplication } from '@angular/platform-browser';
import { provideYamcsWebExtension } from '@yamcs/webapp-sdk';
import { ExternalWebpageComponent } from './external-webpage.component';

// The custom-element tag MUST equal the Yamcs plugin id (artifactId `external-webpage`):
// yamcs-web instantiates <external-webpage> both as a hidden startup initializer and as
// the routed page at /<instance>/ext/external-webpage.
const TAG = 'external-webpage';

(async () => {
  // provideYamcsWebExtension() sets up everything a yamcs-web webcomponent extension needs:
  // base href, Material configuration, the website-config initializer (so getExtraConfig
  // works), zoneless change detection, and Material Symbols icons.
  const app = await createApplication({
    providers: [provideYamcsWebExtension()],
  });

  const element = createCustomElement(ExternalWebpageComponent, {
    injector: app.injector,
  });

  if (!customElements.get(TAG)) {
    customElements.define(TAG, element);
  }
})().catch((err) => console.error(`[${TAG}] failed to initialize`, err));

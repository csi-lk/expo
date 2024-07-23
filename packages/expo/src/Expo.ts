import './Expo.fx';

export { disableErrorHandling } from './errors/ExpoErrorManager';
export { default as registerRootComponent } from './launch/registerRootComponent';

export { isRunningInExpoGo, getExpoGoProjectConfig } from './environment/ExpoGo';

export {
  // Core classes
  EventEmitter,
  type EventSubscription,
  SharedObject,
  SharedRef,
  NativeModule,

  // Methods
  requireNativeModule,
  requireOptionalNativeModule,
  /** @hidden */ requireNativeViewManager,
  reloadAppAsync,

  // Constants
  /** @hidden */ Platform,

  // Hooks
  /** @hidden */ useReleasingSharedObject,
} from 'expo-modules-core';

export { useEvent } from './hooks/useEvent';

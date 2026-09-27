import {useImperativeHandle, useRef, type Ref, type RefObject} from 'react';
import {Commands} from './specs/ALGMenuNativeComponent';
import type {GlassHostRef, GlassMenuHandle} from './types';

/** Exposes the host view's measurement methods and a native open command on `ref`. */
export function useMenuHandle(ref: Ref<GlassMenuHandle> | undefined): RefObject<GlassHostRef | null> {
  const host = useRef<GlassHostRef>(null);
  useImperativeHandle(ref, () => ({
    open: () => { if (host.current) Commands.open(host.current as never); },
    measure: callback => host.current?.measure(callback),
    measureInWindow: callback => host.current?.measureInWindow(callback),
    measureLayout: (relativeTo, onSuccess, onFail) => host.current?.measureLayout(relativeTo, onSuccess, onFail),
    focus: () => host.current?.focus(),
    blur: () => host.current?.blur(),
  }), []);
  return host;
}

import { NetworkFetchError } from './FetchErrors';
import { FetchResponse } from './FetchResponse';
import { NativeRequest, NativeRequestInit, NativeResponse } from './NativeRequest';
import { normalizeBodyInitAsync, normalizeHeadersInit } from './RequestUtils';
import type { FetchRequestInit } from './fetch.types';
import { requireNativeModule } from '../requireNativeModule';

const NetworkFetchModule = requireNativeModule('ExpoNetworkFetchModule');

export async function fetch(url: string, init?: FetchRequestInit): Promise<FetchResponse> {
  const response = new NetworkFetchModule.NativeResponse() as NativeResponse;
  const request = new NetworkFetchModule.NativeRequest(response) as NativeRequest;

  const headers = normalizeHeadersInit(init?.headers);

  const { body: requestBody, overrideHeaders } = await normalizeBodyInitAsync(init?.body);
  if (overrideHeaders) {
    headers.push(...overrideHeaders);
  }

  const nativeRequestInit: NativeRequestInit = {
    credentials: init?.credentials ?? 'include',
    headers,
    method: init?.method ?? 'GET',
  };

  if (init?.signal && init.signal.aborted) {
    throw new NetworkFetchError('The operation was aborted.');
  }
  const abortHandler = () => {
    request.cancel();
  };
  init?.signal?.addEventListener('abort', abortHandler);
  try {
    await request.start(url, nativeRequestInit, requestBody);
  } catch (e: unknown) {
    if (e instanceof Error) {
      throw NetworkFetchError.createFromError(e);
    } else {
      throw new NetworkFetchError(String(e));
    }
  } finally {
    init?.signal?.removeEventListener('abort', abortHandler);
  }
  return new FetchResponse(response);
}

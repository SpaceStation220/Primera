import { useEffect, useRef, useState } from 'react';
import {
  type MusicUploadKind,
  type MusicUploadStatus,
  type PlayAction,
  nativeMusicPages,
  splitMusicDocument,
} from './upload';

type Transfer = {
  id: string;
  kind: MusicUploadKind;
  parts: string[];
  native: boolean;
  playAction?: PlayAction;
  onComplete?: () => void;
};

export function useMusicUpload(
  act: (action: string, payload?: object) => void,
  status?: MusicUploadStatus | null,
  interval = 1000,
) {
  const [transfer, setTransfer] = useState<Transfer | null>(null);
  const [error, setError] = useState('');
  const serial = useRef(0);
  const sent = useRef('');
  const nextSend = useRef(0);
  const send = useRef(act);
  const active = useRef(transfer);
  active.current = transfer;
  send.current = act;
  const next = status?.id === transfer?.id ? status?.next || 0 : 0;
  const state = status?.id === transfer?.id ? status?.state : undefined;
  const serverError = status?.id === transfer?.id ? status?.error : undefined;
  const controlsKey =
    status?.id === transfer?.id
      ? status?.native_controls?.join(';')
      : undefined;

  useEffect(
    () => () => {
      if (active.current)
        send.current('cancel_music_upload', { id: active.current.id });
    },
    [],
  );

  useEffect(() => {
    if (!transfer) return;
    if (state === 'complete' || state === 'error') {
      setError(state === 'error' ? serverError || 'Upload rejected.' : '');
      setTransfer(null);
      if (state === 'complete') transfer.onComplete?.();
      return;
    }
    const preparing = transfer.native && (!state || state === 'preparing');
    const key = `${transfer.id}:${preparing ? 'prepare' : next}`;
    let dispatch: ReturnType<typeof setTimeout>;
    const sendPart = () => {
      const remaining = nextSend.current - performance.now();
      if (remaining > 0) {
        dispatch = setTimeout(sendPart, remaining);
        return;
      }
      if (
        sent.current === key ||
        next >= transfer.parts.length ||
        (transfer.native && state === 'preparing')
      )
        return;
      sent.current = key;
      if (transfer.native) {
        try {
          if (preparing) {
            send.current('begin_native_music_upload', {
              id: transfer.id,
              kind: transfer.kind,
              count: transfer.parts.length,
              size: transfer.parts.reduce(
                (size, page) => size + page.length,
                0,
              ),
              play_action: transfer.playAction,
            });
          } else {
            const controls = controlsKey?.split(';');
            if (controls?.length !== 32)
              throw new Error('The native MIDI transfer bank is unavailable.');
            const page = transfer.parts[next];
            for (let offset = 0; offset < page.length; offset += 1024) {
              Byond.winset(
                controls[offset / 1024],
                'text',
                `${next}:${page.slice(offset, offset + 1024)}`,
              );
            }
            send.current('read_native_music_upload', {
              id: transfer.id,
              index: next,
            });
          }
        } catch (error) {
          send.current('cancel_music_upload', { id: transfer.id });
          setError(String(error));
          setTransfer(null);
          return;
        }
      } else {
        send.current('upload_music_document', {
          id: transfer.id,
          kind: transfer.kind,
          index: next,
          count: transfer.parts.length,
          part: transfer.parts[next],
          play_action: transfer.playAction,
        });
      }
      nextSend.current = performance.now() + Math.max(1000, interval);
    };
    dispatch = setTimeout(
      sendPart,
      Math.max(0, nextSend.current - performance.now()),
    );
    const timeout = setTimeout(
      () => {
        send.current('cancel_music_upload', { id: transfer.id });
        setError(
          'Music upload timed out. The previous composition was not started.',
        );
        setTransfer(null);
      },
      Math.max(15000, interval * 3),
    );
    return () => {
      clearTimeout(dispatch);
      clearTimeout(timeout);
    };
  }, [transfer, next, state, serverError, interval, controlsKey]);

  const upload = (
    kind: Transfer['kind'],
    document: object,
    playAction?: PlayAction,
    onComplete?: () => void,
  ) => {
    if (transfer) return;
    const native = kind === 'sequence' && Byond.IS_BYOND;
    const parts = native
      ? nativeMusicPages(document)
      : splitMusicDocument(document, kind);
    setError('');
    setTransfer({
      id: `${Date.now()}-${++serial.current}`,
      kind,
      parts,
      native,
      playAction,
      onComplete,
    });
  };
  return {
    upload,
    busy: !!transfer,
    error,
    progress: transfer ? `${next}/${transfer.parts.length}` : '',
    cancel: () => {
      if (transfer) send.current('cancel_music_upload', { id: transfer.id });
      setTransfer(null);
    },
  };
}

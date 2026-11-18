import { useEffect, useRef, useState } from 'react';
import {
  type MusicUploadKind,
  type MusicUploadStatus,
  type PlayAction,
  splitMusicDocument,
} from './upload';

type Transfer = {
  id: string;
  kind: MusicUploadKind;
  parts: string[];
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
  send.current = act;
  const next = status?.id === transfer?.id ? status?.next || 0 : 0;
  const state = status?.id === transfer?.id ? status?.state : undefined;
  const serverError = status?.id === transfer?.id ? status?.error : undefined;

  useEffect(() => {
    if (!transfer) return;
    if (state === 'complete' || state === 'error') {
      setError(state === 'error' ? serverError || 'Upload rejected.' : '');
      setTransfer(null);
      if (state === 'complete') transfer.onComplete?.();
      return;
    }
    const key = `${transfer.id}:${next}`;
    let dispatch: ReturnType<typeof setTimeout>;
    const sendPart = () => {
      const remaining = nextSend.current - performance.now();
      if (remaining > 0) {
        dispatch = setTimeout(sendPart, remaining);
        return;
      }
      if (sent.current === key || next >= transfer.parts.length) return;
      sent.current = key;
      send.current('upload_music_document', {
        id: transfer.id,
        kind: transfer.kind,
        index: next,
        count: transfer.parts.length,
        part: transfer.parts[next],
        play_action: transfer.playAction,
      });
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
  }, [transfer, next, state, serverError, interval]);

  const upload = (
    kind: Transfer['kind'],
    document: object,
    playAction?: PlayAction,
    onComplete?: () => void,
  ) => {
    if (transfer) return;
    const parts = splitMusicDocument(document, kind);
    setError('');
    setTransfer({
      id: `${Date.now()}-${++serial.current}`,
      kind,
      parts,
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

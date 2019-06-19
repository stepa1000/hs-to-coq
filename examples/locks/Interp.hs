{-# LANGUAGE GADTs #-}

module Interp where

import           Freer

data Heap = Heap {
    maxLoc  :: Int
  , content :: Int -> Maybe Int }

emptyHeap :: Heap
emptyHeap = Heap 0 (const Nothing)

updateHeap :: Heap -> Int -> Maybe Int -> Heap
updateHeap h loc v = Heap (maxLoc h) newContent where
  newContent n = if n == loc then v else content h n

type Prog = IO' ()

data StopFlag = Unexpected | Blocked | Finished

type Config = (Prog, Heap)

interp :: Prog -> Heap -> Either StopFlag Config
interp (Ret _) _       = Left Finished
interp (Vis (InlF NewMV) k) h = Right (k $ MVar newLoc, Heap newLoc newContent) where
  newLoc = maxLoc h + 1
  newContent n = if n == newLoc then Nothing else content h n
interp (Vis (InlF (TakeMV (MVar loc))) k) h =
  case content h loc of
    Nothing -> Left Blocked
    Just v  -> case decode v of
                 Nothing -> Left Unexpected
                 Just v  -> Right (k v, updateHeap h loc Nothing)
interp (Vis (InlF (ReadMV (MVar loc))) k) h =
  case content h loc of
    Nothing -> Left Blocked
    Just v  -> case decode v of
                 Nothing -> Left Unexpected
                 Just v  -> Right (k v, h)
interp (Vis (InlF (PutMV (MVar loc) v)) k) h =
  case content h loc of
    Nothing -> Right (k (), updateHeap h loc $ Just $ encode v)
    Just _  -> Left Blocked
interp (Vis (InlF (TryTakeMV (MVar loc))) k) h =
  case content h loc of
    Nothing -> Right (k Nothing, h)
    Just v  -> case decode v of
                 Nothing -> Left Unexpected
                 v       -> Right (k v, updateHeap h loc Nothing)
interp (Vis (InlF (TryReadMV (MVar loc))) k) h =
  case content h loc of
    Nothing -> Right (k Nothing, h)
    Just v  -> case decode v of
                 Nothing -> Left Unexpected
                 v       -> Right (k v, h)
interp (Vis (InlF (TryPutMV (MVar loc) v)) k) h =
  case content h loc of
    Nothing -> Right (k True, updateHeap h loc $ Just $ encode v)
    Just _  -> Right (k False, h)
interp (Vis (InlF (IsEmptyMV (MVar loc))) k) h =
  case content h loc of
    Nothing -> Right (k True, h)
    Just _  -> Right (k False, h)
interp (Vis (InrF (ForkIO _)) _) h = Left Unexpected  -- not supported

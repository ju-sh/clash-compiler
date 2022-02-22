{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Clash.FFI.VPI.Parameter
  ( Parameter(..)
  , ConstantType
      ( DecimalConst
      , RealConst
      , BinaryConst
      , OctalConst
      , HexConst
      , StringConst
#if defined(VERILOG_2001)
      , IntConst
#endif
      , TimeConst
      )
  , parameterName
  , parameterFullName
  , parameterSize
  , parameterType
#if defined(VERILOG_2001)
  , parameterIsLocal
  , parameterIsSigned
#endif
  , parameterValue
  , parameterValueAs
  ) where

import           Data.ByteString (ByteString)
import           Data.Proxy (Proxy)
import           Foreign.C.Types (CInt)
import           GHC.Stack (HasCallStack, callStack)
import           GHC.TypeNats

import           Clash.Promoted.Nat

import           Clash.FFI.Monad (SimCont)
import qualified Clash.FFI.Monad as Sim (throw)
import           Clash.FFI.VPI.Object
import           Clash.FFI.VPI.Property
import           Clash.FFI.VPI.Value

newtype Parameter = Parameter { parameterHandle :: Handle }

newtype ConstantType = ConstantType CInt

pattern DecimalConst :: ConstantType
pattern DecimalConst = ConstantType 1

pattern RealConst :: ConstantType
pattern RealConst = ConstantType 2

pattern BinaryConst :: ConstantType
pattern BinaryConst = ConstantType 3

pattern OctalConst :: ConstantType
pattern OctalConst = ConstantType 4

pattern HexConst :: ConstantType
pattern HexConst = ConstantType 5

pattern StringConst :: ConstantType
pattern StringConst = ConstantType 6

#if defined(VERILOG_2001)
pattern IntConst :: ConstantType
pattern IntConst = ConstantType 7
#endif

pattern TimeConst :: ConstantType
pattern TimeConst = ConstantType 8

parameterName :: HasCallStack => Parameter -> SimCont o ByteString
parameterName = receiveProperty VpiName . parameterHandle

parameterFullName :: HasCallStack => Parameter -> SimCont o ByteString
parameterFullName = receiveProperty VpiFullName . parameterHandle

parameterSize :: (HasCallStack, Integral n) => Parameter -> SimCont o n
parameterSize = fmap fromIntegral . getProperty VpiSize . parameterHandle

parameterType :: HasCallStack => Parameter -> SimCont o ConstantType
parameterType = coerceProperty VpiConstType . parameterHandle

#if defined(VERILOG_2001)
parameterIsLocal :: HasCallStack => Parameter -> SimCont o Bool
parameterIsLocal = getProperty VpiLocalParam . parameterHandle

parameterIsSigned :: HasCallStack => Parameter -> SimCont o Bool
parameterIsSigned = getProperty VpiSigned . parameterHandle
#endif

parameterValue :: HasCallStack => Parameter -> SimCont o SomeValue
parameterValue param = do
  size <- parameterSize param

  case someNatVal size of
    SomeNat (proxy :: Proxy sz) ->
      case compareSNat (SNat @1) (snatProxy proxy) of
        SNatLE -> SomeValue <$> parameterValueAs (ObjTypeFmt @sz) param
        SNatGT -> Sim.throw (ZeroWidthValue callStack)

parameterValueAs
  :: (HasCallStack, KnownNat n, 1 <= n)
  => ValueFormat n
  -> Parameter
  -> SimCont o (Value n)
parameterValueAs fmt =
  receiveValue fmt . parameterHandle


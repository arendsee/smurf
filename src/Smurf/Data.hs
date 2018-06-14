module Smurf.Data (
    Top(..)
  , Import(..)
  , Statement(..)
  , Source(..)
  , Expression(..)
  , Primitive(..)
  , BExpr(..)
  , AExpr(..)
  , InputType
  , OutputType
  , Type
  , Constraint
  , Name
) where

import Data.List (intersperse)
import Data.Maybe (maybe)

data Top
  = TopImport Import 
  | TopStatement Statement
  | TopSource Source
  deriving(Show, Ord, Eq)

data Source = Source Name [String] deriving(Ord, Eq)

data Statement
  = Signature Name [InputType] (Maybe OutputType) [Constraint]
  | Declaration Name Expression
  deriving(Show, Ord, Eq)

data Expression
  = ExprPrimitive Primitive
  | ExprApplication Name [Expression]
  deriving(Show, Ord, Eq)

data Primitive
  = PrimitiveInt    Integer
  | PrimitiveReal   Double
  | PrimitiveBool   Bool
  | PrimitiveString String
  deriving(Show, Ord, Eq)

data BExpr
  = BExprName Name
  | BExprBool Bool
  -- relative operators
  | EQ' AExpr AExpr
  | NE' AExpr AExpr
  | GT' AExpr AExpr
  | LT' AExpr AExpr
  | GE' AExpr AExpr
  | LE' AExpr AExpr
  -- logical operators
  | NOT BExpr
  | AND BExpr BExpr
  | OR  BExpr BExpr
  deriving(Show, Ord, Eq)

data AExpr
  = AExprName Name
  | AExprInt Integer
  | AExprReal Double
  | Pos AExpr
  | Neg AExpr
  | Add AExpr AExpr
  | Sub AExpr AExpr
  | Mul AExpr AExpr
  | Div AExpr AExpr
  | Pow AExpr AExpr
  | Mod AExpr AExpr
  | Quo AExpr AExpr
  deriving(Show, Ord, Eq)

data Import = Import {
      importPath :: [Name]
    , importQualifier :: Maybe Name
    , importRestriction :: Maybe [Name]
  } deriving(Show, Ord, Eq)

instance Show Source where
  show (Source n ls) = unlines (("source " ++ n) : ls)

type InputType  = Type
type OutputType = Type
type Type       = String
type Constraint = BExpr
type Name       = String

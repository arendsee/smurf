module Smurf.Parser (smurf) where

import Text.Parsec hiding (State)
import qualified Text.Parsec.Expr as TPE
import Text.Parsec.String (Parser)
import Control.Monad.State

import Smurf.Data
import qualified Smurf.Lexer as Tok

smurf :: Parser [Top]
smurf = do
  Tok.whiteSpace
  result <- many top
  eof
  return result

top :: Parser Top
top =
      try topSource 
  <|> try topStatement
  <|> try topImport
  <?> "Top. Maybe you are missing a semicolon?"

topSource :: Parser Top
topSource = do
  s <- source
  return $ TopSource s

topStatement :: Parser Top
topStatement = do
  s <- statement
  return $ TopStatement s

topImport :: Parser Top
topImport = do
  i <-  try restrictedImport
    <|> try simpleImport
  return $ TopImport i

statement :: Parser Statement
statement = do
  s <-  try signature
    <|> try declaration
  Tok.op ";"
  return $ s

simpleImport :: Parser Import
simpleImport = do
  Tok.reserved "import" 
  path <- Tok.path
  qual <- optionMaybe (Tok.op "as" >> Tok.name)
  return $ Import path qual Nothing

restrictedImport :: Parser Import
restrictedImport = do
  Tok.reserved "from"
  path <- Tok.path
  Tok.reserved "import"
  -- TODO: I am also importing ontologies, how should that be handled?
  -- TODO: at very least, I am also importing types
  functions <- Tok.parens (sepBy1 Tok.name Tok.comma)
  return $ Import path Nothing (Just functions)

-- | parses a 'source' header, returning the language
source :: Parser Source
source = do
  Tok.reserved "source"
  lang <- many1 Tok.nonSpace
  Tok.chop
  source <- many Tok.line
  Tok.whiteSpace
  return $ Source lang source

declaration :: Parser Statement
declaration = do
  varname <- Tok.name
  Tok.op "="
  value <- expression
  return $ Declaration varname value 

expression :: Parser Expression
expression =
      try (Tok.parens expression)
  <|> try application
  <|> try primitiveExpr
  <?> "an expression"

primitiveExpr :: Parser Expression
primitiveExpr = do
  x <- primitive
  return $ ExprPrimitive x

primitive :: Parser Primitive
primitive =
      try Tok.floatP -- this must go before integer
  <|> try Tok.integerP
  <|> try Tok.booleanP
  <|> try Tok.stringLiteralP
  <?> "a primitive"

application :: Parser Expression
application = do
  function <- Tok.name
  arguments <- sepBy expression Tok.whiteSpace
  return $ ExprApplication function arguments

-- | typename :: [input] -> output constraints 
signature :: Parser Statement
signature = do
  function <- Tok.name
  Tok.op "::"
  inputs <- sepBy1 Tok.typename Tok.comma
  output <- optionMaybe (
      Tok.op "->" >>
      Tok.typename
    )
  constraints <- option [] (
      Tok.reserved "where" >>
      Tok.parens (sepBy1 booleanExpr (Tok.op ","))
    )
  return $ Signature function inputs output constraints

booleanExpr :: Parser BExpr
booleanExpr =
      try booleanBinOp
  <|> try relativeExpr
  <|> try not'
  <|> try (Tok.parens booleanExpr)
  <?> "an expression that reduces to True/False"
  where
    not' = do
      Tok.reserved "not"
      e <- booleanExpr
      return $ NOT e

booleanBinOp :: Parser BExpr
booleanBinOp = do
  a <- bterm'
  op <- Tok.logicalBinOp
  b <- bterm'
  return $ binop' op a b
  where
    bterm' = do
      s <-  name'
        <|> bool'
        <|> Tok.parens booleanExpr
        <?> "boolean expression"
      return s

    name' = do
      s <- Tok.name
      return $ BExprName s

    bool' = do
      s <- Tok.boolean
      return $ BExprBool s

    binop' op a b
      | op == "and" = AND a b
      | op == "or"  = OR  a b

relativeExpr :: Parser BExpr
relativeExpr = do
  a <- arithmeticExpr
  op <- Tok.relativeBinOp
  b <- arithmeticExpr
  return $ relop' op a b
  where
    relop' op a b
      | op == "==" = EQ' a b
      | op == "!=" = NE' a b
      | op == ">"  = GT' a b
      | op == "<"  = LT' a b
      | op == ">=" = GE' a b
      | op == "<=" = LE' a b

arithmeticExpr
  = TPE.buildExpressionParser arithmeticTable term
  <?> "expression"

term
  = do
      Tok.parens arithmeticExpr
  <|> val'
  <|> var'
  <?> "simple expression. Currently only integers are allowed"
  where
    val' = do
      x <- primitive
      return $ toExpr' x

    var' = do
      x <- Tok.name
      return $ AExprName x 

    toExpr' :: Primitive -> AExpr
    toExpr' (PrimitiveInt x) = AExprInt x
    toExpr' (PrimitiveReal x) = AExprReal x
    toExpr' _ = undefined

arithmeticTable
  = [
      [ prefix "-" Neg
      , prefix "+" Pos
      ]             
    , [ binary "^"  Pow TPE.AssocRight
      ]
    , [ binary "*"  Mul TPE.AssocLeft
      , binary "/"  Div TPE.AssocLeft
      , binary "%"  Mod TPE.AssocLeft
      , binary "//" Quo TPE.AssocLeft
      ]
    , [ binary "+"  Add TPE.AssocLeft
      , binary "-"  Sub TPE.AssocLeft
      ]
  ]

binary name fun assoc = TPE.Infix  (do{ Tok.op name; return fun }) assoc
prefix name fun       = TPE.Prefix (do{ Tok.op name; return fun })

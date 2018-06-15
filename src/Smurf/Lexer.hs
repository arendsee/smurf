module Smurf.Lexer (
    integer
  , float
  , stringLiteral
  , boolean

  -- fuck this shit
  , integerP
  , floatP
  , stringLiteralP
  , booleanP

  , whiteSpace
  , op
  , reserved
  , name
  , tag
  , specificType
  , genericType
  , nonSpace
  , path
  , comma
  , chop
  , space'
  , line
  , parens
  , braces
  , brackets
  , relativeBinOp
  , logicalBinOp
  , arithmeticBinOp
) where

import Text.Parsec hiding (State)
import Text.Parsec.String (Parser)
import Control.Monad.State
import qualified Data.Char as DC
import qualified Text.Parsec.Language as Lang
import qualified Text.Parsec.Token as Token

import qualified Smurf.Data as D

lexer :: Token.TokenParser ()
lexer = Token.makeTokenParser style
  where
  style = Lang.emptyDef {
            Token.commentLine     = "#"
          , Token.commentStart    = ""
          , Token.commentEnd      = ""
          , Token.nestedComments  = False
          , Token.caseSensitive   = True
          , Token.identStart      = letter <|> char '_'
          , Token.identLetter     = alphaNum <|> oneOf "_.'"
          , Token.opStart         = Token.opLetter Lang.emptyDef
          , Token.opLetter        = oneOf ":!$%&*+./<=>?@\\^|-~"
          , Token.reservedOpNames = [
                "=", "::", ":", "+", "-", "^", "/", "//", "%", "->", ";",
                "(", ")", "{", "}",
                "<", ">", "==", "<=", ">=", "!="
              ]
          , Token.reservedNames = [
                "where"
              , "import"
              , "from"
              , "as"
              , "source"
              , "True"
              , "False"
              , "and"
              , "or"
              , "xor"
              , "nand"
              , "not"
            ]
          }

parens = Token.parens lexer
braces = Token.braces lexer
brackets = Token.brackets lexer

integer    :: Parser Integer
float      :: Parser Double
whiteSpace :: Parser ()
op         :: String -> Parser ()
reserved   :: String -> Parser ()
name       :: Parser String
comma      :: Parser String

integer    = Token.integer lexer
float      = Token.float lexer
whiteSpace = Token.whiteSpace lexer
op         = Token.reservedOp lexer
reserved   = Token.reserved   lexer
name       = Token.identifier lexer
comma      = Token.comma      lexer

tag p =
  option "" (try tag')
  where
    tag' = do
      l <- many1 alphaNum
      whiteSpace
      op ":"
      lookAhead p
      return l

stringLiteral :: Parser String
stringLiteral = do
  _ <- char '"'
  s <- many ((char '\\' >> char '"' ) <|> noneOf "\"")
  _ <- char '"'
  whiteSpace
  return s

boolean :: Parser Bool 
boolean = do
  s <- string "True" <|> string "False"
  whiteSpace
  return $ (read s :: Bool)


integerP :: Parser D.Primitive
integerP = do
  x <- integer
  return $ D.PrimitiveInt x

floatP :: Parser D.Primitive
floatP = do
  x <- float
  return $ D.PrimitiveReal x

stringLiteralP :: Parser D.Primitive 
stringLiteralP = do
  s <- stringLiteral
  return $ D.PrimitiveString s

booleanP :: Parser D.Primitive
booleanP = do
  s <- boolean
  return $ D.PrimitiveBool s

-- | a legal non-generic type name
specificType :: Parser String
specificType = do
  s <- satisfy DC.isUpper
  ss <- many alphaNum
  whiteSpace
  return (s : ss)

genericType :: Parser String
genericType = Token.identifier lexer 

-- | match any non-space character
nonSpace :: Parser Char
nonSpace = noneOf " \n\t\r\v"

path :: Parser [String]
path = do
  path <- sepBy name (char '/')
  whiteSpace
  return path

-- | matches all trailing space
chop :: Parser String
chop = do
  ss <- many space'
  optional newline
  return ss

-- | non-newline space
space' :: Parser Char
space' = char ' ' <|> char '\t'

-- | a raw line with spaces
line :: Parser String
line = do
  s <- many1 space'
  l <- many (noneOf "\n")
  newline
  return $ (s ++ l)

relativeBinOp :: Parser String
relativeBinOp = do
  op <-  (string "==")
     <|> try (string "<=")
     <|> try (string ">=")
     <|> (string "<")
     <|> (string ">")
     <|> (string "!=")
     <?> "a numeric comparison operator" 
  whiteSpace
  return op 

logicalBinOp :: Parser String
logicalBinOp = do
  op <-  (string "and")
     <|> (string "or")
     <|> (string "xor")
     <|> (string "nand")
     <|> (string "not")
     <?> "a logical operator" 
  whiteSpace
  return op 

arithmeticBinOp :: Parser String
arithmeticBinOp = do
  op <-  (string "+")
     <|> (string "-")
     <|> (string "*")
     <|> (string "^")
     <|> (string "%")
     <|> try (string "//")
     <|> (string "/")
     <?> "a numeric operator" 
  whiteSpace
  return op 

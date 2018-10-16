import System.Environment

-- TODO
-- :: Consistency verification function, make sure updates don't break ordering invariants for bug detection
-- :: Add case for less than
-- :: Optimizatioon of propogation: do we need to recurse to all the elements, or is one way enough?

main = do
  s <- readFile "example.txt"
  let tokens = tokenize s
  let comparisonMatrix = [[if (c /= r) then Unknown else Equal | (c, _) <- zipWithIndex tokens] | (r, _) <- zipWithIndex tokens]
  printmatrix comparisonMatrix
  writeFile "sorted.txt" s

-- data definitions for comparison matrix
data ComparisonResult = Less | Equal | More | Unknown deriving (Read, Enum, Eq, Ord)
type ComparisonMatrix = [[ComparisonResult]]

instance Show ComparisonResult where
    show Equal = "   Equal   "
    show Less = "   Less    "
    show More = "   More    "
    show Unknown = "  Unknown  "

-- prints matrix nicely
printmatrix m = putStrLn (unlines (map show m))

opposite :: ComparisonResult -> ComparisonResult
opposite cr
  | cr == More = Less
  | cr == Less = More
  | otherwise = Equal

-- operations on comparison matrix

-- |cascades the new information
-- 1. Update the exact field
-- 2. Update the inverse field
-- 3. Update implied comparisons
{-
Implied comparisons means the assumption of total ordering, but equality is permitted
  - If Equal, no work to be done
  - If rth item More urgent than cth item,
    - then also More than all (c, c*) where (c, c*) = Equal | More, so set (r, c*) to More as well
    - then c also Less than all (r, c*) where(r, c*) = Less | Equal, so set (c, c*) to Less as Well
  - If rth item Less urgent, the opposite of above is true
-}


updateComparison :: Int -> Int -> ComparisonResult -> ComparisonMatrix -> ComparisonMatrix
updateComparison r c comp mat
  | comp == Equal = basicUpdated
  | otherwise = foldr 
                  (\(ri, ci) m -> if (getAt r ci m /= comp) then (updateComparison r ci comp m) else m) 
                  basicUpdated 
                  (indicesWhere (\ri _ v -> ri == c && (v == Equal || v == comp)) basicUpdated)
      where basicUpdated = updateField r c comp (updateField c r (opposite comp) mat)

-- Try:
--
-- let m = [[Equal, Unknown, Unknown], [Equal, Equal, Unknown], [Unknown, Unknown, Equal]]
-- updateComparison 2 1 More m
-- expect: [[Equal,Unknown,Unknown],[More,Equal,Less],[More,More,Equal]]
--
-- let m = [[Equal, Equal, Unknown, Unknown], [Equal, Equal, Less, Unknown], [Unknown, More, Equal, Unknown], [Unknown, Unknown, Unknown, Equal]]
-- [   Equal   ,   Equal   ,  Unknown  ,  Unknown  ]
-- [   Equal   ,   Equal   ,   Less    ,  Unknown  ]
-- [  Unknown  ,   More    ,   Equal   ,  Unknown  ]
-- [  Unknown  ,  Unknown  ,  Unknown  ,   Equal   ]
-- updateComparison 3 2 More m
-- expect: 
-- [   Equal   ,   Equal   ,  Unknown  ,   Less    ]
-- [   Equal   ,   Equal   ,   Less    ,   Less    ]
-- [  Unknown  ,   More    ,   Equal   ,   Less    ]
-- [   More    ,   More    ,   More    ,   Equal   ]

-- let m = [[Equal, More, Unknown, Unknown], [Equal, Equal, More, Unknown], [Unknown, Less, Equal, Unknown], [Unknown, Unknown, Unknown, Equal]]




-- update the field in a given matrix, where
-- - r is the row
-- - c is the column
-- - n is the new value
-- - a is the matrix
updateField :: Int -> Int -> ComparisonResult -> ComparisonMatrix -> ComparisonMatrix
updateField r c n a = [[if (columnIndex == c && rowIndex == r) then n else value  | (columnIndex, value) <- zipWithIndex row]  |(rowIndex, row) <- zipWithIndex a]

-- |returns the list of indices where a given predicate on the tuple (row, column, Value) is true
indicesWhere :: (Int -> Int -> ComparisonResult -> Bool) -> ComparisonMatrix -> [(Int, Int)]
indicesWhere p m = [(ri, ci) | (ri, row) <- zipWithIndex m, (ci, value) <- (zipWithIndex row), p ri ci value]

-- |returns the transformed matrix applied onto the fields which satisfy the predicate
mapWhere :: (Int -> Int -> ComparisonResult -> Bool) -> (Int -> Int -> ComparisonResult -> ComparisonResult) -> ComparisonMatrix -> ComparisonMatrix
mapWhere p f m = [[if (p ri ci value) then  f ri ci value else value | (ci ,value) <- zipWithIndex row]|  (ri, row) <- zipWithIndex m]

-- |returns the item at the given row and column (unsafe!)
getAt r c m = m!!r!!c

-- Tokenizing
-- takes a string and a delimiter, returning just an array of strings
-- default method
tokenize :: String -> [String]
tokenize string = (tokenizeHelper string '\n' [] [])
-- helper
tokenizeHelper :: String -> Char -> String ->  [String] -> [String]
tokenizeHelper [] c currAcc acc = rev acc
tokenizeHelper (h:t) c currAcc acc
  | h == c = tokenizeHelper t c [] (rev currAcc:acc)
  | otherwise = tokenizeHelper t c (h:currAcc) acc

-- util functions
-- reverse
rev lst = foldl (\acc x -> (x:acc)) [] lst

-- zip-with-index
zipWithIndex :: [a] -> [(Int, a)]
zipWithIndex lst = zip [0..(length lst)] lst

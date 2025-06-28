-- ChessLogic Module
local ChessLogic = {}

local directions = {
	Rook = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
	Bishop = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
	Queen = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
	Knight = { { 2, 1 }, { 2, -1 }, { -2, 1 }, { -2, -1 }, { 1, 2 }, { 1, -2 }, { -1, 2 }, { -1, -2 } },
	King = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } },
}

local function inBounds(file, rank)
	return file >= 1 and file <= 8 and rank >= 1 and rank <= 8
end

function ChessLogic.squareToCoords(square)
	local file = string.byte(square:sub(1, 1)) - 64
	local rank = tonumber(square:sub(2, 2))
	return file, rank
end

function ChessLogic.coordsToSquare(file, rank)
	return string.char(file + 64) .. tostring(rank)
end

function ChessLogic.isSquareAttacked(board, square, opponentColor, enPassantTarget)
	local f, r = ChessLogic.squareToCoords(square)
	-- Knight attacks
	for _, dir in pairs(directions.Knight) do
		local nf, nr = f + dir[1], r + dir[2]
		if inBounds(nf, nr) then
			local sq = ChessLogic.coordsToSquare(nf, nr)
			local piece = board[sq]
			if piece and piece.color == opponentColor and piece.type == "Knight" then
				return true
			end
		end
	end
	-- Pawn attacks
	local pawnDir = (opponentColor == "White") and 1 or -1
	for _, df in ipairs({ -1, 1 }) do
		local nf, nr = f + df, r + pawnDir
		if inBounds(nf, nr) then
			local sq = ChessLogic.coordsToSquare(nf, nr)
			local piece = board[sq]
			if piece and piece.color == opponentColor and piece.type == "Pawn" then
				return true
			end
		end
	end
	-- Sliding pieces
	for _, dir in pairs(directions.Rook) do
		local nf, nr = f + dir[1], r + dir[2]
		while inBounds(nf, nr) do
			local sq = ChessLogic.coordsToSquare(nf, nr)
			local piece = board[sq]
			if piece then
				if piece.color == opponentColor and (piece.type == "Rook" or piece.type == "Queen") then
					return true
				end
				break
			end
			nf = nf + dir[1]
			nr = nr + dir[2]
		end
	end
	for _, dir in pairs(directions.Bishop) do
		local nf, nr = f + dir[1], r + dir[2]
		while inBounds(nf, nr) do
			local sq = ChessLogic.coordsToSquare(nf, nr)
			local piece = board[sq]
			if piece then
				if piece.color == opponentColor and (piece.type == "Bishop" or piece.type == "Queen") then
					return true
				end
				break
			end
			nf = nf + dir[1]
			nr = nr + dir[2]
		end
	end
	-- King attacks
	for _, dir in pairs(directions.King) do
		local nf, nr = f + dir[1], r + dir[2]
		if inBounds(nf, nr) then
			local sq = ChessLogic.coordsToSquare(nf, nr)
			local piece = board[sq]
			if piece and piece.color == opponentColor and piece.type == "King" then
				return true
			end
		end
	end
	return false
end

function ChessLogic.findKing(board, color)
	for sq, piece in pairs(board) do
		if piece.color == color and piece.type == "King" then
			return sq
		end
	end
	return nil
end

function ChessLogic.isCheck(board, color)
	local kingPos = ChessLogic.findKing(board, color)
	if not kingPos then
		return false
	end
	local opponent = (color == "White") and "Black" or "White"
	return ChessLogic.isSquareAttacked(board, kingPos, opponent, nil)
end

local function copyBoard(board)
	local newBoard = {}
	for k, v in pairs(board) do
		newBoard[k] = { type = v.type, color = v.color }
	end
	return newBoard
end

function ChessLogic.getLegalMoves(board, square, skipCheckValidation, enPassantTarget)
	local piece = board[square]
	if not piece then
		return {}
	end
	local moves = {}
	local f, r = ChessLogic.squareToCoords(square)
	local opponentColor = (piece.color == "White") and "Black" or "White"

	local function addMove(toF, toR)
		if not inBounds(toF, toR) then
			return
		end
		local toSq = ChessLogic.coordsToSquare(toF, toR)
		local targetPiece = board[toSq]
		if targetPiece == nil or targetPiece.color ~= piece.color then
			if not skipCheckValidation then
				local testBoard = copyBoard(board)
				testBoard[toSq] = testBoard[square]
				testBoard[square] = nil
				if ChessLogic.isCheck(testBoard, piece.color) then
					return
				end
			end
			table.insert(moves, toSq)
		end
	end

	if piece.type == "Pawn" then
		local forwardDir = (piece.color == "White") and 1 or -1
		local oneStep = { f, r + forwardDir }
		local twoStep = { f, r + 2 * forwardDir }
		if inBounds(oneStep[1], oneStep[2]) and not board[ChessLogic.coordsToSquare(oneStep[1], oneStep[2])] then
			addMove(oneStep[1], oneStep[2])
			local startingRank = (piece.color == "White") and 2 or 7
			if r == startingRank and not board[ChessLogic.coordsToSquare(twoStep[1], twoStep[2])] then
				addMove(twoStep[1], twoStep[2])
			end
		end
		for _, df in ipairs({ -1, 1 }) do
			local captureF = f + df
			local captureR = r + forwardDir
			if inBounds(captureF, captureR) then
				local captureSq = ChessLogic.coordsToSquare(captureF, captureR)
				local targetPiece = board[captureSq]
				if (targetPiece and targetPiece.color ~= piece.color) or captureSq == enPassantTarget then
					addMove(captureF, captureR)
				end
			end
		end
	elseif piece.type == "Knight" then
		for _, dir in pairs(directions.Knight) do
			addMove(f + dir[1], r + dir[2])
		end
	elseif piece.type == "Bishop" then
		for _, dir in pairs(directions.Bishop) do
			local nf, nr = f + dir[1], r + dir[2]
			while inBounds(nf, nr) do
				local sq = ChessLogic.coordsToSquare(nf, nr)
				if board[sq] then
					if board[sq].color ~= piece.color then
						addMove(nf, nr)
					end
					break
				else
					addMove(nf, nr)
				end
				nf = nf + dir[1]
				nr = nr + dir[2]
			end
		end
	elseif piece.type == "Rook" then
		for _, dir in pairs(directions.Rook) do
			local nf, nr = f + dir[1], r + dir[2]
			while inBounds(nf, nr) do
				local sq = ChessLogic.coordsToSquare(nf, nr)
				if board[sq] then
					if board[sq].color ~= piece.color then
						addMove(nf, nr)
					end
					break
				else
					addMove(nf, nr)
				end
				nf = nf + dir[1]
				nr = nr + dir[2]
			end
		end
	elseif piece.type == "Queen" then
		for _, dir in pairs(directions.Queen) do
			local nf, nr = f + dir[1], r + dir[2]
			while inBounds(nf, nr) do
				local sq = ChessLogic.coordsToSquare(nf, nr)
				if board[sq] then
					if board[sq].color ~= piece.color then
						addMove(nf, nr)
					end
					break
				else
					addMove(nf, nr)
				end
				nf = nf + dir[1]
				nr = nr + dir[2]
			end
		end
	elseif piece.type == "King" then
		for _, dir in pairs(directions.King) do
			addMove(f + dir[1], r + dir[2])
		end
		-- Castling (simplified: assume king and rook unmoved, spaces empty, not in check)
		if not skipCheckValidation then
			local rank = (piece.color == "White") and 1 or 8
			local opponentColor = (piece.color == "White") and "Black" or "White"
			-- Kingside
			local rookSquareK = ChessLogic.coordsToSquare(8, rank)
			if board[rookSquareK] and board[rookSquareK].type == "Rook" and board[rookSquareK].color == piece.color then
				local emptySquares = { ChessLogic.coordsToSquare(6, rank), ChessLogic.coordsToSquare(7, rank) }
				local blocked = false
				for _, sq in pairs(emptySquares) do
					if board[sq] or ChessLogic.isSquareAttacked(board, sq, opponentColor, enPassantTarget) then
						blocked = true
						break
					end
				end
				if not blocked and not ChessLogic.isCheck(board, piece.color) then
					table.insert(moves, ChessLogic.coordsToSquare(7, rank))
				end
			end
			-- Queenside
			local rookSquareQ = ChessLogic.coordsToSquare(1, rank)
			if board[rookSquareQ] and board[rookSquareQ].type == "Rook" and board[rookSquareQ].color == piece.color then
				local emptySquares = {
					ChessLogic.coordsToSquare(2, rank),
					ChessLogic.coordsToSquare(3, rank),
					ChessLogic.coordsToSquare(4, rank),
				}
				local blocked = false
				for _, sq in pairs(emptySquares) do
					if board[sq] or ChessLogic.isSquareAttacked(board, sq, opponentColor, enPassantTarget) then
						blocked = true
						break
					end
				end
				if not blocked and not ChessLogic.isCheck(board, piece.color) then
					table.insert(moves, ChessLogic.coordsToSquare(3, rank))
				end
			end
		end
	end
	return moves
end

function ChessLogic.isCheckmate(board, color)
	if not ChessLogic.isCheck(board, color) then
		return false
	end
	for square, piece in pairs(board) do
		if piece.color == color then
			local moves = ChessLogic.getLegalMoves(board, square, false, nil)
			if #moves > 0 then
				return false
			end
		end
	end
	return true
end

function ChessLogic.isStalemate(board, color)
	if ChessLogic.isCheck(board, color) then
		return false
	end
	for square, piece in pairs(board) do
		if piece.color == color then
			local moves = ChessLogic.getLegalMoves(board, square, false, nil)
			if #moves > 0 then
				return false
			end
		end
	end
	return true
end

function ChessLogic.serializeBoard(board, turn, enPassantTarget, castlingRights)
	local parts = {}
	for rank = 8, 1, -1 do
		for file = 1, 8 do
			local sq = ChessLogic.coordsToSquare(file, rank)
			local p = board[sq]
			if p then
				table.insert(parts, p.color:sub(1, 1) .. p.type:sub(1, 1))
			else
				table.insert(parts, "  ")
			end
		end
	end
	table.insert(parts, turn:sub(1, 1))
	table.insert(parts, enPassantTarget or "")
	table.insert(parts, castlingRights or "")
	return table.concat(parts, ",")
end

return ChessLogic

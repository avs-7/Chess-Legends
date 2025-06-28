-- Roblox Chess LocalScript with Exit Button + Move History Terminal + Board Labels

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local openEvent = ReplicatedStorage:WaitForChild("OpenChess")
local ChessLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChessLogic"))

local gameOver = false
local squareSize = UDim2.new(0, 60, 0, 60)
local boardFrame
local board = {}
local currentTurn = "White"
local selectedSquare = nil
local enPassantTarget = nil
local repetitionHistory = {}

local pieceDecals = {
	WhitePawn = "rbxassetid://123720442853198",
	WhiteKnight = "rbxassetid://78445382080117",
	WhiteBishop = "rbxassetid://81081286782899",
	WhiteRook = "rbxassetid://110741260228711",
	WhiteQueen = "rbxassetid://121907181363711",
	WhiteKing = "rbxassetid://100680020704115",
	BlackPawn = "rbxassetid://126366982448713",
	BlackKnight = "rbxassetid://101801427935028",
	BlackBishop = "rbxassetid://87072501602384",
	BlackRook = "rbxassetid://72157530506550",
	BlackQueen = "rbxassetid://92559688154307",
	BlackKing = "rbxassetid://80314013396136",
}

-- Move History Terminal Setup --
local terminalGui
local terminalScrollFrame
local terminalLayout
local moveEntries = {}
local moveHighlights = {}

local function createTerminal()
	-- Remove old terminal if exists
	local old = player.PlayerGui:FindFirstChild("MoveTerminalGui")
	if old then
		old:Destroy()
	end

	terminalGui = Instance.new("ScreenGui")
	terminalGui.Name = "MoveTerminalGui"
	terminalGui.ResetOnSpawn = false
	terminalGui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 240, 0, 480)
	frame.Position = UDim2.new(1, -250, 0.5, -240) -- right side of screen
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Parent = terminalGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "Move History"
	title.TextColor3 = Color3.fromRGB(220, 220, 220)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 22
	title.Parent = frame

	terminalScrollFrame = Instance.new("ScrollingFrame")
	terminalScrollFrame.Size = UDim2.new(1, -10, 1, -40)
	terminalScrollFrame.Position = UDim2.new(0, 5, 0, 35)
	terminalScrollFrame.BackgroundTransparency = 1
	terminalScrollFrame.BorderSizePixel = 0
	terminalScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	terminalScrollFrame.ScrollBarThickness = 8
	terminalScrollFrame.Parent = frame

	terminalLayout = Instance.new("UIListLayout")
	terminalLayout.Padding = UDim.new(0, 4)
	terminalLayout.SortOrder = Enum.SortOrder.LayoutOrder
	terminalLayout.Parent = terminalScrollFrame
end

local function addMoveToTerminal(playerColor, moveText)
	if not terminalScrollFrame or not terminalLayout then
		return
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = playerColor .. ": " .. moveText
	label.LayoutOrder = #moveEntries + 1
	label.Parent = terminalScrollFrame

	table.insert(moveEntries, label)

	-- Update scroll size and scroll to bottom
	terminalScrollFrame.CanvasSize = UDim2.new(0, 0, 0, terminalLayout.AbsoluteContentSize.Y)
	terminalScrollFrame.CanvasPosition = Vector2.new(0, terminalLayout.AbsoluteContentSize.Y)
end

local function initBoard()
	board = {}
	local order = { "Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook" }
	for i, piece in ipairs(order) do
		board[string.char(64 + i) .. "1"] = { type = piece, color = "White" }
		board[string.char(64 + i) .. "8"] = { type = piece, color = "Black" }
		board[string.char(64 + i) .. "2"] = { type = "Pawn", color = "White" }
		board[string.char(64 + i) .. "7"] = { type = "Pawn", color = "Black" }
	end
	enPassantTarget = nil
	repetitionHistory = {}
	currentTurn = "White"
	selectedSquare = nil
	gameOver = false
	moveEntries = {}
end

local function clearHighlights()
	for _, highlight in ipairs(moveHighlights) do
		highlight:Destroy()
	end
	moveHighlights = {}
end

local function showHighlights(moves)
	for _, dest in ipairs(moves) do
		local button = boardFrame:FindFirstChild(dest)
		if button then
			local highlight = Instance.new("Frame")
			highlight.Size = UDim2.new(0.5, 0, 0.5, 0)
			highlight.Position = UDim2.new(0.25, 0, 0.25, 0)
			highlight.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			highlight.BackgroundTransparency = 0.3
			highlight.BorderSizePixel = 0
			highlight.ZIndex = 2
			highlight.Parent = button

			table.insert(moveHighlights, highlight)
		end
	end
end

local function updateBoardUI()
	for _, button in pairs(boardFrame:GetChildren()) do
		if button:IsA("ImageButton") then
			local square = button.Name
			local fileByte, rankNum = string.byte(square:sub(1, 1)), tonumber(square:sub(2, 2))
			local isLight = (fileByte + rankNum) % 2 == 0
			button.BackgroundColor3 = isLight and Color3.fromRGB(230, 230, 230) or Color3.fromRGB(50, 50, 50)

			local piece = board[square]
			if piece then
				button.Image = pieceDecals[piece.color .. piece.type] or ""
				button.ImageTransparency = 0
			else
				button.Image = ""
				button.ImageTransparency = 1
			end
		end
	end
end

local function addRepetition()
	local pos = ChessLogic.serializeBoard(board, currentTurn, enPassantTarget, nil)
	table.insert(repetitionHistory, pos)
	local count = 0
	for _, v in ipairs(repetitionHistory) do
		if v == pos then
			count += 1
		end
	end
	return count
end

local function endGame(message)
	gameOver = true
	clearHighlights() -- clear any remaining move highlights
	warn(message)
	addMoveToTerminal("System", message)
end

local function aiMove()
	if gameOver then
		return
	end
	local possibleMoves = {}
	for square, data in pairs(board) do
		if data and data.color == "Black" then
			for _, dest in ipairs(ChessLogic.getLegalMoves(board, square, false, enPassantTarget)) do
				table.insert(possibleMoves, { from = square, to = dest })
			end
		end
	end
	if #possibleMoves == 0 then
		if ChessLogic.isCheckmate(board, "Black") then
			endGame("Checkmate! You Win!")
		elseif ChessLogic.isStalemate(board, "Black") then
			endGame("Stalemate! Draw!")
		end
		return
	end

	local move = possibleMoves[math.random(1, #possibleMoves)] -- simple random AI
	local fromF, fromR = ChessLogic.squareToCoords(move.from)
	local toF, toR = ChessLogic.squareToCoords(move.to)

	board[move.to] = board[move.from]
	board[move.from] = nil

	-- Pawn promotion to queen
	if board[move.to].type == "Pawn" and (toR == 1 or toR == 8) then
		board[move.to].type = "Queen"
	end

	updateBoardUI()
	addMoveToTerminal("Black", move.from .. " → " .. move.to)

	if ChessLogic.isCheckmate(board, "White") then
		endGame("Checkmate! Black Wins!")
		return
	elseif ChessLogic.isStalemate(board, "White") then
		endGame("Stalemate! Draw!")
		return
	elseif addRepetition() >= 3 then
		endGame("Draw by threefold repetition!")
		return
	end

	currentTurn = "White"
end

local function createChessUI()
	if player.PlayerGui:FindFirstChild("ChessGui") then
		player.PlayerGui.ChessGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessGui"
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui

	boardFrame = Instance.new("Frame")
	boardFrame.Size = UDim2.new(0, 480, 0, 480)
	boardFrame.Position = UDim2.new(0.5, -240, 0.5, -240)
	boardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	boardFrame.Parent = gui

	-- Board Labels: Files (a-h) and Ranks (1-8)
	local files = { "a", "b", "c", "d", "e", "f", "g", "h" }
	for i, fileLetter in ipairs(files) do
		-- Bottom labels
		local bottomLabel = Instance.new("TextLabel")
		bottomLabel.Size = UDim2.new(0, 60, 0, 20)
		bottomLabel.Position = UDim2.new(0, (i - 1) * 60, 1, 0) -- below board
		bottomLabel.BackgroundTransparency = 1
		bottomLabel.Text = fileLetter
		bottomLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		bottomLabel.Font = Enum.Font.SourceSansBold
		bottomLabel.TextSize = 18
		bottomLabel.Parent = boardFrame

		-- Top labels
		local topLabel = Instance.new("TextLabel")
		topLabel.Size = UDim2.new(0, 60, 0, 20)
		topLabel.Position = UDim2.new(0, (i - 1) * 60, 0, -20) -- above board
		topLabel.BackgroundTransparency = 1
		topLabel.Text = fileLetter
		topLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		topLabel.Font = Enum.Font.SourceSansBold
		topLabel.TextSize = 18
		topLabel.Parent = boardFrame
	end

	for rank = 1, 8 do
		local rankNum = tostring(rank)
		-- Left labels
		local leftLabel = Instance.new("TextLabel")
		leftLabel.Size = UDim2.new(0, 20, 0, 60)
		leftLabel.Position = UDim2.new(0, -20, 0, (8 - rank) * 60) -- left side
		leftLabel.BackgroundTransparency = 1
		leftLabel.Text = rankNum
		leftLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		leftLabel.Font = Enum.Font.SourceSansBold
		leftLabel.TextSize = 18
		leftLabel.Parent = boardFrame

		-- Right labels
		local rightLabel = Instance.new("TextLabel")
		rightLabel.Size = UDim2.new(0, 20, 0, 60)
		rightLabel.Position = UDim2.new(1, 0, 0, (8 - rank) * 60) -- right side
		rightLabel.BackgroundTransparency = 1
		rightLabel.Text = rankNum
		rightLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		rightLabel.Font = Enum.Font.SourceSansBold
		rightLabel.TextSize = 18
		rightLabel.Parent = boardFrame
	end

	-- Create Exit Button
	local exitButton = Instance.new("TextButton")
	exitButton.Size = UDim2.new(0, 100, 0, 40)
	exitButton.Position = UDim2.new(0.5, -50, 1, -50)
	exitButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	exitButton.TextColor3 = Color3.new(1, 1, 1)
	exitButton.Font = Enum.Font.SourceSansBold
	exitButton.TextSize = 24
	exitButton.Text = "Exit Game"
	exitButton.Parent = gui

	exitButton.MouseButton1Click:Connect(function()
		gameOver = true
		if boardFrame then
			boardFrame:Destroy()
		end
		if gui then
			gui:Destroy()
		end
		if terminalGui then
			terminalGui:Destroy()
		end
	end)

	for file = 1, 8 do
		for rank = 1, 8 do
			local squareName = string.char(64 + file) .. rank
			local button = Instance.new("ImageButton")
			button.Size = squareSize
			button.Position = UDim2.new(0, (file - 1) * 60, 0, (8 - rank) * 60)
			button.Name = squareName
			button.BackgroundColor3 = ((file + rank) % 2 == 0) and Color3.fromRGB(230, 230, 230)
				or Color3.fromRGB(50, 50, 50)
			button.BorderSizePixel = 0
			button.Image = ""
			button.Parent = boardFrame

			button.MouseButton1Click:Connect(function()
				if gameOver or currentTurn ~= "White" then
					return
				end
				if selectedSquare then
					local legalMoves = ChessLogic.getLegalMoves(board, selectedSquare, false, enPassantTarget)
					for _, dest in ipairs(legalMoves) do
						if dest == squareName then
							local fromF, fromR = ChessLogic.squareToCoords(selectedSquare)
							local toF, toR = ChessLogic.squareToCoords(squareName)

							enPassantTarget = nil
							if board[selectedSquare].type == "Pawn" and math.abs(toR - fromR) == 2 then
								local epRank = (fromR + toR) / 2
								enPassantTarget = ChessLogic.coordsToSquare(fromF, epRank)
							end

							board[squareName] = board[selectedSquare]
							board[selectedSquare] = nil

							if board[squareName].type == "Pawn" and squareName == enPassantTarget then
								local capRank = (board[squareName].color == "White") and toR - 1 or toR + 1
								local capSquare = ChessLogic.coordsToSquare(toF, capRank)
								board[capSquare] = nil
							end

							if board[squareName].type == "King" then
								if selectedSquare == "E1" and squareName == "G1" then
									board["F1"] = board["H1"]
									board["H1"] = nil
								elseif selectedSquare == "E1" and squareName == "C1" then
									board["D1"] = board["A1"]
									board["A1"] = nil
								elseif selectedSquare == "E8" and squareName == "G8" then
									board["F8"] = board["H8"]
									board["H8"] = nil
								elseif selectedSquare == "E8" and squareName == "C8" then
									board["D8"] = board["A8"]
									board["A8"] = nil
								end
							end

							if board[squareName].type == "Pawn" and (toR == 8 or toR == 1) then
								board[squareName].type = "Queen"
							end

							updateBoardUI()
							addMoveToTerminal("White", selectedSquare .. " → " .. squareName)

							if ChessLogic.isCheckmate(board, "Black") then
								endGame("Checkmate! You Win!")
								return
							elseif ChessLogic.isStalemate(board, "Black") then
								endGame("Stalemate! Draw!")
								return
							end

							if addRepetition() >= 3 then
								endGame("Draw by threefold repetition!")
								return
							end

							clearHighlights()
							selectedSquare = nil
							currentTurn = "Black"
							task.wait(0.5)
							aiMove()
							return
						end
					end
					selectedSquare = nil
				elseif board[squareName] and board[squareName].color == "White" then
					selectedSquare = squareName
					clearHighlights()
					local legalMoves = ChessLogic.getLegalMoves(board, selectedSquare, false, enPassantTarget)
					showHighlights(legalMoves)
				end
			end)
		end
	end

	initBoard()
	updateBoardUI()
	createTerminal()
end

openEvent.OnClientEvent:Connect(createChessUI)

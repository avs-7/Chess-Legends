local ReplicatedStorage = game:GetService("ReplicatedStorage")

local openEvent = ReplicatedStorage:FindFirstChild("OpenChess")
if not openEvent then
	openEvent = Instance.new("RemoteEvent")
	openEvent.Name = "OpenChess"
	openEvent.Parent = ReplicatedStorage
end

local chessPart = workspace:FindFirstChild("ChessPart")
if not chessPart then
	chessPart = Instance.new("Part")
	chessPart.Name = "ChessPart"
	chessPart.Size = Vector3.new(6, 1, 6)
	chessPart.Position = Vector3.new(0, 5, 0)
	chessPart.Anchored = true
	chessPart.BrickColor = BrickColor.new("Reddish brown")
	chessPart.TopSurface = Enum.SurfaceType.Smooth
	chessPart.BottomSurface = Enum.SurfaceType.Smooth
	chessPart.Parent = workspace
end

local prompt = chessPart:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Play Chess"
	prompt.ObjectText = "Chessboard"
	prompt.HoldDuration = 0.5
	prompt.Parent = chessPart
end

prompt.Triggered:Connect(function(player)
	openEvent:FireClient(player)
end)

--!strict
local Config = {
	GROUND_Y = 0,
	GRAVITY = 100,

	STAGE_BOUNDS = {
		minX = -54,
		maxX = 58,
		minY = -12,
		maxY = 52,
	},

	SLINGSHOT_ANCHOR = Vector3.new(-36, 7, 0),
	PULL_MIN = 1.2,
	PULL_MAX = 8.5,
	GRAB_RADIUS = 5.5,
	LAUNCH_SPEED_PER_STUD = 11.5,

	DOT_COUNT = 18,
	DOT_DT = 0.08,

	BIRD_RADIUS = 1.35,
	PIG_RADIUS = 1.4,
	BLOCK_DEPTH = 2.2,

	SPAWN_GRACE_SEC = 0.6,
	MIN_IMPACT_SPEED = 7.0,
	DAMAGE_PER_SPEED = 2.6,
	PAIR_COOLDOWN_SEC = 0.15,

	SETTLE_SPEED_THRESHOLD = 0.7,
	SETTLE_HOLD_SEC = 0.65,
	MAX_FLIGHT_SEC = 7.0,
	MAX_SETTLE_SEC = 4.0,
	WIN_DELAY_SEC = 0.85,

	UNUSED_BIRD_BONUS = 10000,

	CAMERA = {
		fov = 22,
		center = Vector3.new(-1, 12.5, 0),
		width = 102,
		height = 36,
	},

	Bird = {
		density = 1.6,
		friction = 0.5,
		elasticity = 0.3,
		color = Color3.fromRGB(215, 42, 42),
	},

	Pig = {
		hp = 26,
		density = 0.8,
		friction = 0.6,
		elasticity = 0.2,
		score = 5000,
		color = Color3.fromRGB(106, 198, 66),
		damagedColor = Color3.fromRGB(76, 148, 48),
	},

	Materials = {
		Glass = {
			hp = 18,
			density = 0.55,
			friction = 0.35,
			elasticity = 0.15,
			score = 500,
			color = Color3.fromRGB(165, 225, 248),
			damagedColor = Color3.fromRGB(115, 175, 205),
			transparency = 0.32,
			robloxMaterial = Enum.Material.Glass,
		},
		Wood = {
			hp = 42,
			density = 0.9,
			friction = 0.65,
			elasticity = 0.12,
			score = 750,
			color = Color3.fromRGB(186, 132, 74),
			damagedColor = Color3.fromRGB(132, 86, 44),
			transparency = 0,
			robloxMaterial = Enum.Material.WoodPlanks,
		},
		Stone = {
			hp = 90,
			density = 2.0,
			friction = 0.8,
			elasticity = 0.08,
			score = 1000,
			color = Color3.fromRGB(132, 138, 146),
			damagedColor = Color3.fromRGB(88, 92, 98),
			transparency = 0,
			robloxMaterial = Enum.Material.Concrete,
		},
	},

	CollisionGroups = {
		Bird = "AB_Bird",
		Block = "AB_Block",
		Pig = "AB_Pig",
		Ground = "AB_Ground",
		NoCollide = "AB_NoCollide",
	},
}

return Config

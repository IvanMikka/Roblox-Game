-- ItemsConfig (ModuleScript) - v1.0
-- Единый каталог всех предметов в игре.

local ItemsConfig = {

	--[[
		РУКОВОДСТВО ПО СВОЙСТВАМ ПРЕДМЕТА:
		- Name: Название, которое видит игрок.
		- Description: Описание при наведении.
		- GridSize: Размер в сетке инвентаря (X, Y).
		- GridIcon: ID картинки для сетки инвентаря ("тетрис").
		- HotbarIcon: ID картинки для хотбара и слотов экипировки (компактная версия).
		- EquipSlot: В какой слот экипировки можно надеть предмет ("Head", "Torso", "Accessory", "Backpack").
		- IsStackable: Можно ли складывать в стопку (true/false).
		- MaxStack: Максимальное количество в стопке.
		- IsTwoHanded: Занимает ли обе руки в хотбаре (true/false).
		- Model: Путь к 3D-модели, которая появляется при выбрасывании.
	]]


	-- CURRENCY
	["Money"] = {
		Name = "Coins",
		Description = "Universal currency.",
		GridSize = Vector2.new(1, 1),
		GridIcon = "rbxassetid://95108647984745",
		HotbarIcon = "rbxassetid://133884176424484",
		IsStackable = true,
		MaxStack = 256,
		EquipSlot = "Money",
	},

	-- WEAPONS & TOOLS
	["Sword"] = {
		Name = "Homemade combat knife",
		Description = "A long, curved sword. Requires space in the inventory.",
		GridSize = Vector2.new(1, 3),
		GridIcon = "rbxassetid://107983310410220",
		HotbarIcon = "rbxassetid://91003319475511",
		IsTwoHanded = false,
		WeaponModel = "Sword",
		Model = "HomemadeCombatKnife(Weapon)",
		Weapon = {
			DamageType = "Melee",
			DamageMultiplier = 2.0,     -- ?2 к базовому урону «кулака»
			LightCooldownScale = 1.5,   -- ?1.5 к базовому КД лёгкой атаки
			HeavyEnabled = false,       -- запрет тяжёлых ударов
			AnimSet = {
				OneHand = { "Melee_Light1", "Melee_Light2", "Melee_Light3" },
				TwoHand = { "Melee_Light1", "Melee_Light2", "Melee_Light3" } -- пока те же клипы
			}
		}
	},
	["Shield"] = {
		Name = "Wooden shield",
		Description = "A sturdy wooden shield.",
		GridSize = Vector2.new(2, 2),
		GridIcon = "rbxassetid://74924644487603",
		HotbarIcon = "rbxassetid://80578938461395",
		IsTwoHanded = false,
	},
	["Rifle"] = {
		Name = "Artisanal Hunting Rifle",
		Description = "Heavy and bulky, but powerful. Occupies both hands.",
		GridSize = Vector2.new(4, 2),
		GridIcon = "rbxassetid://75085386791014",
		HotbarIcon = "rbxassetid://74401036533272",
		IsTwoHanded = true,
		WeaponModel = "Rifle",
		Model = "ArtisanalRifle(Weapon)",
	},
	["Pistol"] = {
		Name = "Homemade pistol",
		Description = "A reliable one-handed weapon.",
		GridSize = Vector2.new(2, 2),
		GridIcon = "rbxassetid://102064371556433",
		HotbarIcon = "rbxassetid://77587869621469",
		IsTwoHanded = false,
	},

	-- CONSUMABLES
	["Ammo"] = {
		Name = "Ammo",
		Description = "A box of ammo for a pistol.",
		GridSize = Vector2.new(1, 1),
		GridIcon = "rbxassetid://87348570170722",
		HotbarIcon = "rbxassetid://118982083106775",
		IsStackable = true,
		MaxStack = 30,
	},

	-- EQUIPMENT
	["TravelSack"] = {
		Name = "Travel Sack",
		Description = "A simple sack that expands inventory. Slows you down by 5%.",
		GridSize = Vector2.new(4, 4),
		GridIcon = "rbxassetid://93780134179163",
		HotbarIcon = "rbxassetid://95171760208897",
		EquipSlot = "Accessory",
		ExpansionSize = Vector2.new(5, 4),
		SpeedModifier = -0.05
	},
	["SquireBackpack"] = {
		Name = "Squire's Backpack",
		Description = "A sturdy backpack for a loyal squire. Slows you down by 15%.",
		GridSize = Vector2.new(5, 6),
		GridIcon = "rbxassetid://140269384934130",
		HotbarIcon = "rbxassetid://95171760208897",
		EquipSlot = "Accessory",
		ExpansionSize = Vector2.new(7, 10),
		SpeedModifier = -0.15
	},
	["CombatPouchSystem"] = {
		Name = "Combat Pouch System",
		Description = "An advanced, lightweight pouch system that doesn't hinder movement.",
		GridSize = Vector2.new(4, 3),
		GridIcon = "rbxassetid://102064635222339",
		HotbarIcon = "rbxassetid://95171760208897",
		EquipSlot = "Accessory",
		ExpansionSize = Vector2.new(5, 7),
		SpeedModifier = 0
	},
	["Armor"] = {
		Name = "Leather Vest",
		Description = "Provides excellent protection, but is very bulky.",
		GridSize = Vector2.new(4, 4),
		GridIcon = "rbxassetid://71737970102605",
		HotbarIcon = "rbxassetid://7779489144",
		EquipSlot = "Armor",
		Model = "Jacket(Armor)",
	},
	["CylinderHat"] = {
		Name = "Top Hat",
		Description = "An elegant headpiece. Hides hair.",
		GridSize = Vector2.new(2, 2),
		GridIcon = "rbxassetid://107003350914121",
		HotbarIcon = "rbxassetid://105419671964675",
		EquipSlot = "Accessory",
	},
	["Scarf"] = {
		Name = "Scarf",
		Description = "Protects from dust and wind.",
		GridSize = Vector2.new(2, 1),
		GridIcon = "rbxassetid://107683598120340",
		HotbarIcon = "rbxassetid://76514106809850",
		EquipSlot = "Accessory",
	},
}

return ItemsConfig
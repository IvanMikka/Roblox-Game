Представь что ты профессиональный программист. Мне нужна помощь в роблокс студии, в скриптинге.  разрабатываю что-то типа приключенческого плейса с системой сражения, движения и тп. Вот состав моих скриптов:
ReplicatedStorage:
-Events(Folder) - для RemoteEvent
-Lootables(Folder) - для моделей лутбоксов
-Weapons(Folder) - для моделей оружия
-AssetsConfig(Module) - Ассет вещей из каталога роблокса
-CharacterCore.shared(Module) - Модуль для управления Ядром режима
-ItemsConfig(Module) - Конфиг с характеристиками предметов
-StatusTabsUI(Module) - Модуль для правильной работы язычков для отображения активных игровых эффектов

ServerScriptService:
-CharacterBlood.server(Script) - Скрипт для управления показателем крови
-CharacterCore.server(Script) - Ядро режима, для управления скриптами управления персонажем
-CombatSystemServer(Script) - Серверная часть системы боя
-EventsInitializer(Script) - Инициализатор событий
-LootManager(Script) - Скрипт управления лутбоксам
-PlayerConnectionManager(Script) - Скрип, управляющий подключениями
-TestingManager(Script) - Скрипт для создания тестовых предметов
-UniversalDummyController(Script) - Скрипт для управления Думми
-DamageModule(ModuleScript) - Обработчик урона
-DataManager(ModuleScript) - Управление данными
-HitboxManagerModule(ModuleScript) - Управление хитбоксами
-InventoryController(ModuleScript) - Серверная часть системы инвентаря
-MenuManagerModule(ModuleScript) - Серверная часть системы начального меню
-SoundManager(ModuleScript) - Управление звуками
-StateManager(ModuleScript) - Управление состоянием персонажа
-WeaponManager(ModuleScript) - Менеджер оружия

StarterPlayer:
-StarterPlayerScripts:
--MenuSystem(Folder):
---Main(LocalScript) - Главная часть системы меню
---CameraManager(ModuleScript) - Управление камерой в меню
---EditorManager(ModuleScript) - Управление редактором
---InventoryManager(ModuleScript) - Управление инвентарем
---NotificationManager(ModuleScript) - Система сообщений
---ShopManager(ModuleScript) - Управление донатом
---SoundManagerClient(ModuleScript) - Клиентская часть управления звуками
---UIManager(ModuleScript) - UI менеджер
--CharacterCore.client(LocalScript) - Клиентская часть ядра
--CombatSystemClient(LocalScript) - Клиентская часть системы боя
--LootBillboardClient(LocalScript) - Скрипт для кастомных меню подбора лута
--MovemetSystem(LocalScript) - Система движения
--ShiftLock(LocalScript) - Переназначение шифтлока
--StatusTabsClient(LocalScript) - Клиентская часть для язычков состояния

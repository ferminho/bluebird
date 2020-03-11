// -------------------------------------------
// BlueBird
// by Ferminho 2020
// done FOR DivCompo 2020 -- long live DIV!
//
// Licensed under> check LICENSE file
// -------------------------------------------


//--------------------------------------------
PROGRAM bluebird;
//--------------------------------------------
CONST

   BASE_PATH = "ferminho\bluebird\";

   // Dev config
   DEVELOPER_MODE = true;
   STARTING_LEVEL = 0;
   SKIP_LOGOS = true;
   SKIP_MENU = true;
   SKIP_INTRO = true;
   LOGGING = true;
   LOG_FILE = "bluebird.log";

   // Drawing parameters
   SCREEN_RES = m320x240;
   SCREEN_WIDTH = 320;
   SCREEN_HEIGHT = 240;
   SCREEN_RESTORE = no_restore; // no_restore, partial_restore, complete_restore
   SCREEN_DUMP = complete_dump; // partial_dump, complete_dump
   TARGET_FPS = 100;
   MAX_FRAMESKIP = 2;
   MAIN_REGION = 1;

   // Math AND physics
   G_RES = 1000;        // GLOBAL RESOLUTION / precision TO be used throughout all processes
   TRIGO_RES = 10;      // Resolution FOR trigonometry
   G_TO_TRIGO_DIV = 100;// From GLOBAL TO trigo resolution division (multiply IF the other way around)
   G_RES_90 = 90 * G_RES;
   G_RES_360 = 360 * G_RES;

   // Camera properties
   HFOV = 72000;
   VFOV = 59000;
   HALF_HFOV = HFOV / 2;
   HALF_VFOV = VFOV / 2;
   GROUND_MARGIN = 10;
   CAMERA_ACCEL = 100;  // units / s^2
   MAX_CAMERA_VEL = 300;// units / s

   // Dynamic graph definitions
   ENTITY_ANGLES = 32;
   ENTITY_ANGLE_STEP = G_RES_360 / ENTITY_ANGLES;

   // Bird properties
   BIRD_SCALING = 15;   // %
   BIRD_2D_SIZE = 45;   // size of 2D sprite (ship itself, NOT container map)
   BIRD_HALF_2D_SIZE = BIRD_2D_SIZE / 2;
   BIRD_SLOW_SPEED = 225;
   BIRD_STD_SPEED = 450;
   BIRD_HIGH_SPEED = 675;
   BIRD_CLOSE_DISTANCE = 128;
   BIRD_STD_DISTANCE = 160;
   BIRD_LONG_DISTANCE = 192;
   BIRD_MAX_VEL = 400; // "2D" speed
   BIRD_MAIN_GRAPH = 1;
   BIRD_AIM_DIST_X = 25000;
   BIRD_MAX_AIM_ANGLE = 35000; // angle (GRES) at which TO shoot at max 2D speed

   // Other ship properties
   FEN_CAR_SCALING = 80;
   FEN_CAR_FRONT_GRAPH = 1;
   FEN_CAR_BACK_GRAPH = 1 + ENTITY_ANGLES;

   // Weapon properties
   VULKAN_FIRE_ACCEL = 2000; // in 0.5s it will be rolling at 1000 rps (firing speed)
   VULKAN_FIRE_DECCEL = 1000; // when at 1000 rps, in 1s it will stop rolling
   VULKAN_FIRE_INTERVAL = 125; // 8 bullets x 2 vulkans (like in BlueBird) = 16 bullets per second!
   VULKAN_SHOT_SPEED = 1000; // units / s
   VULKAN_SHOT_RADIUS = 5;

   // Process priority
   PRIORITY_TIME_MASTER =     max_int;
   PRIORITY_PLAYER_INPUT =     100000;
   PRIORITY_RAIL_OPERATOR =     90000;
   PRIORITY_BIRD =               1000;
   PRIORITY_BIRD_SIGHTS =         900;
   PRIORITY_BIRD_VULKANS =        800;
   PRIORITY_BIRD_SHOT =           100;
   PRIORITY_CAMERA =          -100000;

   // Mode8
   MAIN_M8 = 0;
   MAX_M8_COORD = 30208 * G_RES;
   M8_DEFAULT_STEP = 0; // no wallclimb by default
   M8_Z_OFFSET = 7;

   // Menu navigation
   MENU_STATE_ENTERING = 0;
   MENU_STATE_RUNNING = 1;
   MENU_STATE_EXITING = 2;

   MENU_ACTION_NONE = 0;
   MENU_ACTION_ENTER = 1;
   MENU_ACTION_EXIT = 2;

   MENU_ITEM_Y = 100;
   MENU_ITEM_HEIGHT = 20;
   MENU_ITEM_DELAY = 10;
   MENU_ITEM_DEFAULT = -1;

   // Effects
   FADE_SPEED = 10; // standard fade speed FOR transitions

   // Input
   I_PLAYER = 0;

   // Action system
   ACTION_NONE = 0;
   ACTION_DIE = 1;  // kill the PROCESS, NOT dying in terms of character death
   // Camera actions
   ACTION_SPECTATE_PLAYER = 10;
   // Rail actions
   ACTION_ACTIVATE_RAIL = 20;
   // Bird actions
   // Bird children actions
   ACTION_FIRE = 150;

   // Level definition constants
   LEVEL_DEF_FILE = "levels.dat";
   LEVEL_MAX_LEVELS = 10;
   LEVEL_MAX_BLOCKS = 100;

   BLOCK_FLAG_REPEAT_WHILE_ENEMIES = 1; // obvious
   BLOCK_FLAG_FULL_CYCLES = 2;          // IF repeating, never finish mid-cycle, always complete cycle

   TIMER_GLOBAL = 9;

GLOBAL

   INT game_status; // current status, usually ID of game status handler
   INT lev; // current level - name is unusually short FOR commodity

   // Levels definitions
   //    Since Div is NOT very fond of dynamic data structures, there are some "fixed big STRUCT arrays".
   STRUCT levels[LEVEL_MAX_LEVELS]
      STRING name;   // "" = empty
      // Resources
      STRUCT res
         STRING wld_path;
         STRING fpg_path;
      END
      // Info about visuals, FX, etc
      STRUCT visual
         BYTE fog_color[2];
         BYTE fog_distance[1];
      END
      // World-related coords AND dimensions, all in simple res
      STRUCT coords
         INT camera_z;
         INT area_width;
         INT area_height;
         INT area_gap;
         // "Range" stands FOR the rail box dimensions definition. X AND Z are absolute values, Y is relative
         WORD area_x_abs_range[1];
         INT area_y_rel_range[1];
         WORD area_z_abs_range[1];
      END
      // Blocks definition include the sucession of areas, as well as enemy waves
      INT blocks_count;
      STRUCT blocks[LEVEL_MAX_BLOCKS]
         STRING areas; // areas in 2-digit space-delimited STRING (e.g. "00 12 01 01 03"), "" = empty block
         // watch out, do NOT add starting OR trailing spaces. Don't OR don't. There is no trim.
         INT flags;  // block properties, DEFAULT 0
         STRING enemies; // enemy wave info in EDBBSL
      END
   END

   // Rail: info about the current "rail" the camera AND player are following, in realtime
   STRUCT level_rail
      INT teleport_pxd, INT teleport_pyd; // (G_RES) teleport OFFSET/delta during teleport FRAME
      // Coords
      INT px, INT py, INT pz; // (G_RES) updated every FRAME with base-px,py,pz
      INT x, INT y, INT z; // in simple res
      // Position within rail blocks defined in level
      // Block: current block
      // Block_cycle: current cycle withing block (0..n), i.e. number of times it has been repeated
      //    Makes sense only when a REPEAT-flag is active
      // Block_area: current area INDEX within block (first = 0, second = 1...)
      // Area: current area (area ID, FROM 0 TO n depending on grid size)
      INT block, INT block_cycle, INT block_area, INT area;
      // Rail box limits in G_RES (the box moves with the rail alongside the X axis)
      INT box_min_py, INT box_max_py;
      INT box_min_pz, INT box_max_pz;
      // Area absolute limits in G_RES, updated after every area change
      INT area_min_px, INT area_max_px;
      INT area_min_py, INT area_max_py;
      INT area_min_pz, INT area_max_pz;

   END

   // World grid info in G_RES
   STRUCT grid
      INT x0, INT y0, INT x1;
      INT cell_width, INT cell_height;
      INT rows, INT columns;
   END

   // Resources: file res
   fpg_level;  // FPG handle of current level WLD
   fpg_bird;  // FPG handle of bird library
   fpg_flying_enemies;  // FPG handle of flying enemies library
   fpg_misc;   // FPG handle of misc sprites
   wld_level;  // WLD handle of current level

   // Resources: enemy base graphs
   INT base_graphs[1];

   // Important processes
   id_rail_operator;
   id_camera;
   id_player;

   // Game logic timing (transformed)
   INT delta;
   INT global_time;
   INT time_speed = 1000;

   // Input
   STRUCT input[0]
      INT x;         // -100 TO 100
      INT y;         // -100 TO 100
      INT throttle;  // -1 TO 1
      fire;          // true OR false
   END

   // Math
   INT psin[3599];
   INT pcos[3599];
   INT ptan[3599];
   INT half_hfov_tan; // tan of half the HFOV
   INT half_vfov_tan; // tan of half the VFOV

   STRUCT menu
     state, action, num_items, shown_items, active_item;
   END

LOCAL

   // Game status PROCESS is binded TO; it will be destroyed IF game status changes
   INT binded_game_status;

   // Precision coordinates in G_RES resolution. This pz is meant FOR m8, NOT z-depth
   INT px, INT py, INT pz;

   // Roll, pitch angles (remember old "angle" is yaw in m8)
   INT roll, pitch;
   // Graph FOR entity angle 0 (first angle STEP)
   base_graph;

   // Velocity in units per second
   INT vx, INT vy, INT vz;

   // Action system
   action;

BEGIN

   init();

   log_formatted("[Footer]", false);

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME STATUS MANAGEMENT
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION init();
//--------------------------------------------
BEGIN

   log_formatted("[Header]", false);

   log("Loading levels in " + BASE_PATH + LEVEL_DEF_FILE);
   load(BASE_PATH + LEVEL_DEF_FILE, &levels);

   set_mode(SCREEN_RES);
   // I've changed this because the menu is
   // wrongly rendered.
   //restore_type = SCREEN_RESTORE;
   //dump_type = SCREEN_DUMP;
   set_fps(TARGET_FPS, MAX_FRAMESKIP);
   define_region(MAIN_REGION, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

   init_precalculated_trigonometry();

   time_master(); // this should always be running
   player_input(); // same goes FOR player input

   IF (!SKIP_MENU)
      menu_main();
   ELSE
      level(STARTING_LEVEL);
   END

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME STATUS MANAGEMENT
// ----------------------------------------------------------

//--------------------------------------------
// Menu item.
//--------------------------------------------
PROCESS menu_item(POINTER text)
PRIVATE
  index, timer_start;
BEGIN
  index = menu.num_items;

  menu.num_items++;

  graph = write_in_map(0, text, 0);
  y = MENU_ITEM_Y + (index * MENU_ITEM_HEIGHT);

  IF (menu.active_item == index)
    flags = 0;
  ELSE
    flags = 4;
  END

  // Menu item enters.
  timer_start = timer + ((index + 1) * 50);
  WHILE (timer - timer_start < 50)
    x = quadratic(50, clamp(timer - timer_start, 0, 50), -100, 75, 50);
    FRAME;
  END
  x = 50;

  menu.shown_items++;

  WHILE (menu.action == MENU_ACTION_NONE)
    IF (menu.active_item == index)
      flags = 0;
    ELSE
      flags = 4;
    END
    FRAME;
  END

  timer_start = timer + ((index + 1) * 50);
  WHILE (timer - timer_start < 50)
    x = quadratic(50, clamp(timer - timer_start, 0, 50), 50, 75, -100);
    FRAME;
  END
  x = 50;

  menu.shown_items--;

END

//--------------------------------------------
// Main menu
//--------------------------------------------
PROCESS menu_main()
BEGIN
  menu_reset(0);

  menu_item("Un jugador");
  menu_item("Dos jugadores");
  menu_item("Opciones");
  menu_item("Creditos");
  menu_item("Salir");

  menu_loop();

  IF (menu.action == MENU_ACTION_ENTER)
    SWITCH (menu.active_item)
      CASE 0:
        level(STARTING_LEVEL);
      END
      CASE 1:
        level(STARTING_LEVEL);
      END
      CASE 2:
        // TODO: Opciones
        menu_not_implemented();
      END
      CASE 3:
        // TODO: Creditos
        menu_not_implemented();
      END
      CASE 4:
        menu_exit();
      END
    END
  END

  IF (menu.action == MENU_ACTION_EXIT)
    menu_exit();
  END
END

//--------------------------------------------
// Resets menu options.
//--------------------------------------------
FUNCTION menu_reset(active_item)
BEGIN
  menu.num_items = 0;
  IF (menu.active_item >= 0)
    menu.active_item = active_item;
  END
END

//--------------------------------------------
//
//
//
//--------------------------------------------
FUNCTION menu_loop()
BEGIN
  menu.state = MENU_STATE_ENTERING;
  WHILE (menu.shown_items < menu.num_items)
    FRAME;
  END
  menu.state = MENU_STATE_RUNNING;
  WHILE (menu.action == MENU_ACTION_NONE)
    IF (key(_up) OR joy.up)
      menu.active_item--;
      IF (menu.active_item < 0)
        menu.active_item = menu.num_items - 1;
      END
      wait(MENU_ITEM_DELAY);
    END

    IF (key(_down) OR joy.down)
      menu.active_item++;
      IF (menu.active_item >= menu.num_items)
        menu.active_item = 0;
      END
      wait(MENU_ITEM_DELAY);
    END

    IF (key(_space) OR key(_enter) OR joy.button1)
      menu.action = MENU_ACTION_ENTER;
      wait(MENU_ITEM_DELAY);
    END

    IF (key(_esc) OR joy.button2)
      menu.action = MENU_ACTION_EXIT;
      wait(MENU_ITEM_DELAY);
    END
    FRAME;
  END
  menu.state = MENU_STATE_EXITING;
  WHILE (menu.shown_items > 0)
    FRAME;
  END
END

FUNCTION menu_exit()
BEGIN
  exit("Gracias por jugar!", 0);
END

FUNCTION menu_not_implemented()
BEGIN
  exit("No implementado :(", 1);
END

//--------------------------------------------


//--------------------------------------------
PROCESS level(INT new_level);
//--------------------------------------------
BEGIN

   game_status = ID;
   log("Playing level " + itoa(new_level));

   IF (levels[new_level].name == "")
      log("Level " + itoa(new_level) + " NOT defined. Returning");
      RETURN;
   END

   lev = new_level;
   // Common FPGs are loaded AND re-processed each level TO allow FOR multiple palettes
   // (FOR that, we'd need several pre-paletted FPGs though)
   load_level_resources(new_level);

   post_process();
   id_rail_operator = rail_operator();
   id_camera = camera();
   id_player = bird();

   start_mode8(id_camera, MAIN_M8, MAIN_REGION);
   set_env_color(levels[lev].visual.fog_color[0],
                 levels[lev].visual.fog_color[1],
                 levels[lev].visual.fog_color[2]);
   set_fog(levels[lev].visual.fog_distance[0],
           levels[lev].visual.fog_distance[1]);

   IF (DEVELOPER_MODE)
      write_debug_info();
   END

   fade_and_wait(100, 100, 100, FADE_SPEED);

   id_rail_operator.action = ACTION_ACTIVATE_RAIL;
   id_camera.action = ACTION_SPECTATE_PLAYER;

   LOOP
      FRAME;
   END

END
//--------------------------------------------



// ----------------------------------------------------------
// ------------- INPUT
// ----------------------------------------------------------


//--------------------------------------------
PROCESS player_input();
//--------------------------------------------
BEGIN

   LOOP
      input[I_PLAYER].x            = 0;
      input[I_PLAYER].y            = 0;
      input[I_PLAYER].throttle     = 0;
      input[I_PLAYER].fire         = false;

      IF (key(_a)) input[I_PLAYER].x = -100; END
      IF (key(_d)) input[I_PLAYER].x = 100; END
      IF (key(_w)) input[I_PLAYER].y = 100; END
      IF (key(_s)) input[I_PLAYER].y = -100; END
      IF (key(_q)) input[I_PLAYER].throttle = -1; END
      IF (key(_e)) input[I_PLAYER].throttle = 1; END
      IF (key(_space)) input[I_PLAYER].fire = true; END

      FRAME;
   END

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME ENTITIES & WORLD
// ----------------------------------------------------------


//--------------------------------------------
PROCESS rail_operator();
//--------------------------------------------
BEGIN

   action = ACTION_NONE;
   binded_game_status = game_status;
   priority = PRIORITY_RAIL_OPERATOR;

   calculate_grid_info();

   // atm this won't change, all levels keep the same rail Z
   pz = levels[lev].coords.camera_z * G_RES;

   // first block/area teleport
   level_rail.block = -1;
   level_rail.block_area = -1;
   level_rail.px = 0;
   level_rail.py = 0;
   advance_rail_block_area();
   px += level_rail.teleport_pxd;
   py += level_rail.teleport_pyd;
   level_rail.teleport_pxd = 0; // don't propagate teleport info this time
   level_rail.teleport_pyd = 0;

   vx = BIRD_STD_SPEED;

   WHILE (game_status == binded_game_status)

      IF (action == ACTION_ACTIVATE_RAIL)
         px += vx * delta;

         IF (px >= grid.x1)
            // CHANGE AREA
            advance_rail_block_area();

            px += level_rail.teleport_pxd;
            py += level_rail.teleport_pyd;
         ELSE
            level_rail.teleport_pxd = 0;
            level_rail.teleport_pyd = 0;
         END
      END

      level_rail.px = px;
      level_rail.py = py;
      level_rail.pz = pz;

      level_rail.x = level_rail.px / G_RES;
      level_rail.y = level_rail.py / G_RES;
      level_rail.z = level_rail.pz / G_RES;
      FRAME;
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION calculate_grid_info();
//--------------------------------------------
PRIVATE

   INT area_w, INT area_h, INT area_gap, INT area_x0, INT area_x1;

BEGIN

   area_w = levels[lev].coords.area_width;
   area_h = levels[lev].coords.area_height;
   area_gap = levels[lev].coords.area_gap;
   area_x0 = levels[lev].coords.area_x_abs_range[0];
   area_x1 = levels[lev].coords.area_x_abs_range[1];

   // calculate the map "grid" coords AND dimensions
   grid.x0 = area_x0 * G_RES;
   grid.y0 = (area_h * G_RES) / 2;
   grid.x1 = area_x1 * G_RES;
   grid.cell_width = (area_w + area_gap) * G_RES;
   grid.cell_height = (area_h + area_gap) * G_RES;
   grid.rows = MAX_M8_COORD / grid.cell_height;
   grid.columns = MAX_M8_COORD / grid.cell_width;

END
//--------------------------------------------


//--------------------------------------------
FUNCTION advance_rail_block_area();
//--------------------------------------------
// This FUNCTION knows about parsing block area definitions
PRIVATE

   STRING str;
   INT str_length;
   is_first_cycle, is_last_area, enemies_alive, flag_rwe, flag_fc;
   INT rel_min_y, INT rel_max_y;
   INT grid_i, INT grid_j; // position within grid matrix (i, j) i = row, j = col

BEGIN

   rel_min_y = levels[lev].coords.area_y_rel_range[0] * G_RES;
   rel_max_y = levels[lev].coords.area_y_rel_range[1] * G_RES;

   IF (level_rail.block == -1)
      // First block/area
      level_rail.block = 0;
      level_rail.block_area = 0;
      level_rail.block_cycle = 0;
   ELSE
      strcpy(str, levels[lev].blocks[level_rail.block].areas);
      str += " ";
      str_length = strlen(str);
      is_first_cycle = level_rail.block_cycle == 0;
      is_last_area = level_rail.block_area == ((str_length / 3) - 1);
      enemies_alive = are_enemies_alive();
      flags = levels[lev].blocks[level_rail.block].flags;
      flag_rwe = (flags & BLOCK_FLAG_REPEAT_WHILE_ENEMIES) == BLOCK_FLAG_REPEAT_WHILE_ENEMIES;
      flag_fc = (flags & BLOCK_FLAG_FULL_CYCLES) == BLOCK_FLAG_FULL_CYCLES;
      IF ((is_last_area AND NOT (flag_rwe AND enemies_alive))
          OR (NOT is_last_area AND NOT is_first_cycle AND NOT flag_fc AND NOT enemies_alive))
         // Jump TO next block
         level_rail.block += 1;
         level_rail.block_area = 0;
         level_rail.block_cycle = 0;
      ELSE IF (is_last_area AND flag_rwe AND enemies_alive)
         // Repeat another cycle
         level_rail.block_area = 0;
         level_rail.block_cycle += 1;
      ELSE
         // Advance 1 block area
         level_rail.block_area += 1;
      END END
   END

   // Parse area
   strcpy(str, levels[lev].blocks[level_rail.block].areas);
   str += " "; // one trailing space TO make it multiple of 3 chars
   str_length = strlen(str);
   strdel(str, level_rail.block_area * 3, str_length - (level_rail.block_area * 3) - 2);
   level_rail.area = calculate(str);

   // Calculate target coords
   grid_j = level_rail.area / grid.rows;
   grid_i = level_rail.area MOD grid.rows;
   IF (grid_j >= grid.rows)
      log("ERROR: tried TO jump TO grid (" + itoa(grid_i) + ", " + itoa(grid_j) + ")");
      log("  Max: (" + itoa(grid.rows - 1) + ", " + itoa(grid.columns - 1) + ")");
      log("  Reading: block " + itoa(level_rail.block)
          + " block_area " + itoa(level_rail.block_area)
          + " area " + itoa(level_rail.area));
      exit("Grid jump out of range", -1);
   END
   x = grid.x0 + (grid_j * grid.cell_width); // in G_RES
   y = grid.y0 + (grid_i * grid.cell_height); // in G_RES

   // Update rail box limits
   level_rail.box_min_py = y + rel_min_y;
   level_rail.box_max_py = y + rel_max_y;
   level_rail.box_min_pz = levels[lev].coords.area_z_abs_range[0] * G_RES;
   level_rail.box_max_pz = levels[lev].coords.area_z_abs_range[1] * G_RES;

   // Update area limits
   level_rail.area_min_px = grid_j * grid.cell_width;
   level_rail.area_max_px = level_rail.area_min_px + levels[lev].coords.area_width * G_RES;
   level_rail.area_min_py = grid_i * grid.cell_height;
   level_rail.area_max_py = level_rail.area_min_py + levels[lev].coords.area_height * G_RES;
   level_rail.area_min_pz = levels[lev].coords.area_z_abs_range[0] * G_RES; // FOR now, fixed
   level_rail.area_max_pz = levels[lev].coords.area_z_abs_range[1] * G_RES; // FOR now, fixed

   // Make everyone jump TO the candidate block/area
   level_rail.teleport_pxd = x - level_rail.px;
   level_rail.teleport_pyd = y - level_rail.py;

END
//--------------------------------------------


//--------------------------------------------
FUNCTION is_inside_current_area();
//--------------------------------------------
BEGIN
   x = father.px;
   y = father.py;
   z = father.pz;

   RETURN(x > level_rail.area_min_px
          AND x < level_rail.area_max_px
          AND y > level_rail.area_min_py
          AND y < level_rail.area_max_py
          AND z > level_rail.area_min_pz
          AND z < level_rail.area_max_pz);
END
//--------------------------------------------


//--------------------------------------------
FUNCTION are_enemies_alive();
//--------------------------------------------
BEGIN
   // TODO: add all enemy types
   RETURN(get_id(TYPE flying_enemy));
END
//--------------------------------------------


//--------------------------------------------
PROCESS camera();
//--------------------------------------------
PRIVATE

   INT rail_y_range;       // in G_RES
   INT rail_z_range;       // in G_RES
   INT half_rail_y_range;  // in simple res
   INT half_rail_z_range;  // in simple_res

   // all these TO calculate the 3D-2D conversions AND player positioning on screen
   INT player_dx;
   INT player_hres; // horiz resolution at player plane visible on screen (higher when farther)
   INT player_vres;
   INT player_ratio; // -1.0 TO 1.0 on the rail_*_range (0.0 = center). In G_RES
   INT camera_max_pos; // temp var used TO determine camera pos FOR player_*_ratio = 1.0

   INT target_y, INT target_z;

BEGIN

   rail_y_range = levels[lev].coords.area_y_rel_range[1]
             - levels[lev].coords.area_y_rel_range[0];
   half_rail_y_range = rail_y_range / 2;
   rail_z_range = levels[lev].coords.area_z_abs_range[1]
             - levels[lev].coords.area_z_abs_range[0];
   half_rail_z_range = rail_z_range / 2;
   rail_y_range += BIRD_2D_SIZE; // TO include full ship in view
   rail_y_range *= G_RES;
   rail_z_range += BIRD_2D_SIZE + GROUND_MARGIN; // same AND also let some margin TO ground
   rail_z_range *= G_RES;

   binded_game_status = game_status;
   ctype = c_m8;
   priority = PRIORITY_CAMERA;

   py = level_rail.py;
   pz = level_rail.pz;
   radius = 0;
   height = 0;
   m8.height = 0;

   WHILE (game_status == binded_game_status)

      px = level_rail.px;
      py += level_rail.teleport_pyd;
      target_y = level_rail.py;
      target_z = level_rail.pz;

      IF (action == ACTION_SPECTATE_PLAYER)
         player_dx = id_player.x - level_rail.x;
         player_hres = player_dx * 2 * half_hfov_tan;
         player_vres = player_dx * 2 * half_vfov_tan;

         IF (player_hres < rail_y_range)
            player_ratio = ((id_player.y - level_rail.y) * G_RES) / half_rail_y_range;
            camera_max_pos = (rail_y_range - player_hres) / 2;
            target_y += (camera_max_pos / G_RES) * player_ratio;
         END

         IF (player_vres < rail_z_range)
            player_ratio = id_player.z + BIRD_HALF_2D_SIZE; // position correction
            player_ratio = ((player_ratio - level_rail.z) * G_RES) / half_rail_z_range;
            camera_max_pos = (rail_z_range - player_vres) / 2;
            target_z += ((camera_max_pos / G_RES) * player_ratio) - (GROUND_MARGIN * G_RES);
         END
      END

      // smooth approximation
      py = (target_y * 75 + py * 25) / 100;
      pz = (target_z * 75 + pz * 25) / 100;

      x = px / G_RES;
      y = py / G_RES;
      z = pz / G_RES;
      FRAME;
   END

END
//--------------------------------------------


//--------------------------------------------
PROCESS bird();
//--------------------------------------------
PRIVATE

   INT vel_mod;
   INT clamp_factor;
   INT max_roll;
   sights, vulkan_l, vulkan_r;
   INT aim_angle_y, INT aim_angle_z; // aim angles in G_RES

BEGIN

   priority = PRIORITY_BIRD;
   binded_game_status = game_status;

   ctype = c_m8;
   file = fpg_bird;
   base_graph = BIRD_MAIN_GRAPH;

   px = level_rail.px + (BIRD_STD_DISTANCE * G_RES);
   py = level_rail.py;
   pz = level_rail.pz - BIRD_HALF_2D_SIZE;
   radius = BIRD_HALF_2D_SIZE;
   height = BIRD_2D_SIZE;

   sights = bird_sights();
   vulkan_l = bird_vulkan(2500, -BIRD_HALF_2D_SIZE * 500, -BIRD_HALF_2D_SIZE * 500);
   vulkan_r = bird_vulkan(2500, BIRD_HALF_2D_SIZE * 500, -BIRD_HALF_2D_SIZE * 500);

   WHILE (game_status == binded_game_status)

      px = level_rail.px + (BIRD_STD_DISTANCE * G_RES);
      py += level_rail.teleport_pyd;

      // Movement
      vx = id_rail_operator.vx; // saved but not applied directly
      vy += (input[I_PLAYER].x * 7 * delta) / G_RES;
      vz += (input[I_PLAYER].y * 7 * delta) / G_RES;
      vel_mod = sqrt(vy * vy + vz * vz);
      IF (vel_mod > BIRD_MAX_VEL)
         clamp_factor = (BIRD_MAX_VEL * G_RES) / vel_mod;
         vel_mod = BIRD_MAX_VEL;
         vy = (vy * clamp_factor) / G_RES;
         vz = (vz * clamp_factor) / G_RES;
      END

      py += vy * delta;
      pz += vz * delta;

      IF (py < level_rail.box_min_py) py = level_rail.box_min_py; vy = 0; END
      IF (py > level_rail.box_max_py) py = level_rail.box_max_py; vy = 0; END
      IF (pz < level_rail.box_min_pz) pz = level_rail.box_min_pz; vz = 0; END
      IF (pz > level_rail.box_max_pz) pz = level_rail.box_max_pz; vz = 0; END

      // Rolling
      max_roll = (100000 * vel_mod) / BIRD_MAX_VEL;
      roll = roll - (vy >> 1) * delta;
      roll = clamp(roll, -max_roll, max_roll + 10000);

      // Aiming (set 'aiming yaw & pitch' TO let sights AND vulkans update based on this)
      // This yaw/angle & pitch will be ignored FOR drawing, it's meant only FOR aiming
      angle = (BIRD_MAX_AIM_ANGLE * vy) / BIRD_MAX_VEL;
      pitch = (BIRD_MAX_AIM_ANGLE * vz) / BIRD_MAX_VEL;

      // Shooting
      IF (input[I_PLAYER].fire)
         vulkan_l.action = ACTION_FIRE;
         vulkan_r.action = ACTION_FIRE;
      ELSE
         vulkan_l.action = ACTION_NONE;
         vulkan_r.action = ACTION_NONE;
      END

      x = px / G_RES;
      y = py / G_RES;
      z = pz / G_RES;

      graph = get_entity_angle_graph(base_graph, roll);
      FRAME;
   END

END
//--------------------------------------------


//--------------------------------------------
PROCESS bird_sights();
//--------------------------------------------
BEGIN

   priority = PRIORITY_BIRD_SIGHTS;
   binded_game_status = game_status;
   ctype = c_m8;
   m8_step = M8_DEFAULT_STEP;
   file = fpg_misc;
   graph = 50;
   flags = 4;

   WHILE (game_status == binded_game_status)

      angle = father.angle MOD G_RES_360;
      IF (angle < 0) angle += G_RES_360; END
      pitch = father.pitch MOD G_RES_360;
      IF (pitch < 0) pitch += G_RES_360; END

      px = father.px + BIRD_AIM_DIST_X;
      py = father.py;
      py += (BIRD_AIM_DIST_X * psin[angle / G_TO_TRIGO_DIV]) / G_RES;
      pz = father.pz + BIRD_HALF_2D_SIZE * G_RES;
      pz += (BIRD_AIM_DIST_X * psin[pitch / G_TO_TRIGO_DIV]) / G_RES;

      x = px / G_RES;
      y = py / G_RES;
      z = (pz / G_RES) - 10; // m8 positioning correction (half graph height)
      FRAME;
   END
END
//--------------------------------------------


//--------------------------------------------
PROCESS bird_vulkan(INT pxd, INT pyd, INT pzd);
//--------------------------------------------
PRIVATE

   INT next_bullet_time = -1;
   INT accel;
   INT rolling_speed = 0; // 0 TO 1 * G_RES
   INT shown_frames_left;

BEGIN

   priority = PRIORITY_BIRD_VULKANS;
   binded_game_status = game_status;
   ctype = c_m8;
   m8_step = M8_DEFAULT_STEP;
   file = fpg_misc;

   WHILE (game_status == binded_game_status)
      // keep velocity up-to-date as shots apply relative speed to father velocity
      vx = father.vx;
      vy = father.vy;
      vz = father.vz;

      IF (shown_frames_left == 0)
         graph = 0;
      ELSE
         shown_frames_left --;
      END

      angle = father.roll / G_TO_TRIGO_DIV; // trick: it will be almost normalized
      IF (angle < 0) angle += 3600; END       // but it could be negative
      px = father.px + pxd;
      py = father.py;
      pz = father.pz + (BIRD_HALF_2D_SIZE * G_RES);
      py += (pyd * pcos[angle] - pzd * psin[angle]) / G_RES;
      pz += (pyd * psin[angle] + pzd * pcos[angle]) / G_RES;

      x = px / G_RES;
      y = py / G_RES;
      z = (pz / G_RES) - 5; // m8 positioning correction (half graph height)

      IF (action == ACTION_FIRE)
         accel = rand((VULKAN_FIRE_ACCEL * 50) / 100, VULKAN_FIRE_ACCEL);
         rolling_speed += (accel * delta) / G_RES;
         IF (rolling_speed >= 1000)
            rolling_speed = 1000;
            IF (next_bullet_time == -1 OR global_time >= next_bullet_time)
               IF (rand(1, 100) <= 75)
                  graph = 60 + rand(0, 299) / 100;
                  shown_frames_left = rand(20, 99) / 20;
               END
               bird_shot(px, py, pz, father.angle, father.pitch);
               next_bullet_time = global_time + VULKAN_FIRE_INTERVAL;
            END
         END

      ELSE
         rolling_speed -= (VULKAN_FIRE_DECCEL * delta) / G_RES;
         IF (rolling_speed <= 0)
            rolling_speed = 0;
            next_bullet_time = -1;
         END

      END

      FRAME;
   END
END
//--------------------------------------------


//--------------------------------------------
PROCESS bird_shot(INT px, INT py, INT pz, INT angle, INT pitch);
//--------------------------------------------
PRIVATE

   INT pxd, INT pyd, INT pzd; // precision coord deltas (quantity to move each frame)
   // movement must be performed in radius-sized steps to avoid crossing walls
   INT steps; // number of steps to be performed
   INT current_step; // current step number (0-based)

BEGIN

   priority = PRIORITY_BIRD_SHOT;
   binded_game_status = game_status;
   ctype = c_m8;
   m8_step = M8_DEFAULT_STEP;
   radius = VULKAN_SHOT_RADIUS;
   file = fpg_misc;
   graph = 70;

   apply_shperical_velocity(VULKAN_SHOT_SPEED, pitch, angle);
   vx += father.vx;
   vy += father.vy;
   vz += father.vz;
   x = px / G_RES;
   y = py / G_RES;
   z = pz / G_RES;
   steps = (sqrt(vx * vx + vy * vy + vz * vz) + radius - 1) / radius; // radius-1 = manual way of doing 'ceil'

   WHILE (game_status == binded_game_status
          AND action != ACTION_DIE)

      px += level_rail.teleport_pxd;
      py += level_rail.teleport_pyd;

      pxd = vx * delta;
      pyd = vy * delta;
      pzd = vz * delta;

      REPEAT
         current_step ++;
         x = (px + ((pxd * current_step) / steps)) / G_RES;
         y = (py + ((pyd * current_step) / steps)) / G_RES;
         z = (pz + ((pzd * current_step) / steps)) / G_RES - (radius / 2);
         FRAME(0);
      UNTIL (current_step >= steps OR m8_wall != -1)

      // update pxyz with latest position, which could be any mid-position
      px += (pxd * current_step) / steps;
      py += (pyd * current_step) / steps;
      pz += (pzd * current_step) / steps;

      IF (is_inside_current_area() AND m8_wall == -1)
         FRAME;
      ELSE
         action = ACTION_DIE;
      END
   END
END
//--------------------------------------------


//--------------------------------------------
PROCESS flying_enemy();
//--------------------------------------------
BEGIN
   // TODO
END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- RESOURCE MANAGEMENT
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION load_level_resources(INT new_level);
//--------------------------------------------
BEGIN

   load_pal(BASE_PATH + levels[lev].res.fpg_path);
   fpg_level = load_fpg(BASE_PATH + levels[lev].res.fpg_path);
   wld_level = load_wld(BASE_PATH + levels[lev].res.wld_path, fpg_level);
   fpg_bird = load_fpg(BASE_PATH + "fpg\bird.fpg");
   fpg_flying_enemies = load_fpg(BASE_PATH + "fpg\fen.fpg");
   fpg_misc = load_fpg(BASE_PATH + "fpg\misc.fpg");
   log("Loaded resources FOR level " + itoa(new_level));

   preprocess_resources();
   log("Preprocessed resources FOR level " + itoa(new_level));
END
//--------------------------------------------


//--------------------------------------------
FUNCTION preprocess_resources();
//--------------------------------------------
BEGIN

   preprocess_angles(fpg_bird, 900, BIRD_MAIN_GRAPH, BIRD_SCALING);
   preprocess_angles(fpg_flying_enemies, 900, FEN_CAR_FRONT_GRAPH, FEN_CAR_SCALING);
   preprocess_angles(fpg_flying_enemies, 901, FEN_CAR_BACK_GRAPH, FEN_CAR_SCALING);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION preprocess_angles(file, graph, start_graph, INT size);
//--------------------------------------------
PRIVATE

   INT i;
   INT graph_width, INT graph_height;

BEGIN

   FOR (i = 0; i < ENTITY_ANGLES; i+= 1)
      graph_width = graphic_info(file, start_graph + i, g_wide);
      graph_height = graphic_info(file, start_graph + i, g_height);

      angle = i * ENTITY_ANGLE_STEP;
      map_xput(file, start_graph + i, graph, graph_width / 2, graph_height / 2, angle, size, 0);
   END

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- VISUAL EFFECTS & GFX FUNCTIONS
// ----------------------------------------------------------


//--------------------------------------------
PROCESS post_process();
//--------------------------------------------
PRIVATE

   INT drawing1, INT drawing2;

BEGIN

   binded_game_status = game_status;
   priority = min_int;
   z = min_int;

   IF (DEVELOPER_MODE)
      drawing1 = draw(1, 222, 7, 0, 158, 120, 162, 120);
      drawing2 = draw(1, 222, 7, 0, 160, 118, 160, 122);
   END

   WHILE (game_status == binded_game_status)
      FRAME;
   END

   IF (DEVELOPER_MODE)
      delete_draw(drawing1);
      delete_draw(drawing2);
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION fade_and_wait(INT r, INT g, INT b, INT speed);
//--------------------------------------------
BEGIN

   fade(r, g, b, speed);

   WHILE (fading)
      FRAME;
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION get_entity_angle_graph(base_graph, INT angle);
//--------------------------------------------
BEGIN

   angle = angle MOD G_RES_360;
   IF (angle < 0) angle += G_RES_360; END
   RETURN(base_graph + (angle / ENTITY_ANGLE_STEP));

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- MATH & PHYSICS
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION init_precalculated_trigonometry();
//--------------------------------------------
PRIVATE

   INT i, total;

BEGIN

   total = 360 * TRIGO_RES;

   FOR (i = 0; i < total; i += 1)
      psin[i] = (sin(i * G_TO_TRIGO_DIV) * G_RES) / 1000;
      pcos[i] = (cos(i * G_TO_TRIGO_DIV) * G_RES) / 1000;
      ptan[i] = (tan(i * G_TO_TRIGO_DIV) * G_RES) / 1000;
   END
   half_hfov_tan = tan(HALF_HFOV);
   half_vfov_tan = tan(HALF_VFOV);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION clamp(INT value, INT min, INT max);
//--------------------------------------------
BEGIN

   IF (value <= min) RETURN(min); END
   IF (value >= max) RETURN(max); END
   RETURN(value);

END
//--------------------------------------------


//--------------------------------------------
// Applies spherical vector to father vx,vy,vz
// radius = vector radius/modulus in G_RES
// theta = inclination (pitch) in G_RES
// phi = azimuth/yaw in G_RES
FUNCTION apply_shperical_velocity(INT radius, INT theta, INT phi);
//--------------------------------------------
BEGIN
   // +90� in -theta to adapt to the spherical system where theta grows from Z axis to +XY plane
   theta = (-theta + G_RES_90) MOD G_RES_360;
   IF (theta < 0) theta += G_RES_360; END
   theta /= G_TO_TRIGO_DIV;
   phi = phi MOD G_RES_360;
   IF (phi < 0) phi+= G_RES_360; END
   phi /= G_TO_TRIGO_DIV;

   father.vx = radius;
   father.vx = (father.vx * psin[theta]) / G_RES;
   father.vx = (father.vx * pcos[phi]) / G_RES;
   father.vy = radius;
   father.vy = (father.vx * psin[theta]) / G_RES;
   father.vy = (father.vx * psin[phi]) / G_RES;
   father.vz = (radius * pcos[theta]) / G_RES;
END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- SYSTEM & DEBUGGING
// ----------------------------------------------------------


//--------------------------------------------
PROCESS time_master();
//--------------------------------------------
PRIVATE

   INT last_timer = 0;
   INT carry_out = 0;  // remaining decimals FROM previous FRAME

BEGIN

   priority = PRIORITY_TIME_MASTER;

   LOOP
      delta = timer - last_timer;
      last_timer += delta;
      // transform delta TO G_RES scale (NOT necessarily 1/100s as in timer[])
      delta = (delta * G_RES) / 100;

      // transform with speed, keeping carry out FOR next FRAME
      delta = (delta * time_speed) + carry_out;
      carry_out = delta % G_RES;
      delta /= G_RES;

      global_time += delta;

      IF (DEVELOPER_MODE)
         IF (key(_f1))
            time_speed = (time_speed * 98) / 100;
         ELSE IF (key(_f2))
            IF (time_speed < 50)
               time_speed = 50;
            ELSE
               time_speed = (time_speed * 102) / 100;
               IF (time_speed > 10000) time_speed = 10000; END
            END
         END END
      END

      FRAME;
   END

END
//--------------------------------------------


//--------------------------------------------
PROCESS write_debug_info();
//--------------------------------------------
BEGIN

   write    (0, 0 , 0 , 0, "CX");
   write_int(0, 20, 0 , 0, &id_camera.x);
   write    (0, 0 , 8 , 0, "CY");
   write_int(0, 20, 8 , 0, &id_camera.y);
   write    (0, 0 , 16, 0, "CZ");
   write_int(0, 20, 16, 0, &id_camera.z);

   write    (0, 0 , 32, 0, "FPS");
   write_int(0, 20, 32, 0, &fps);
   write    (0, 0 , 40, 0, "TS");
   write_int(0, 20, 40, 0, &time_speed);
   write    (0, 0 , 48, 0, "d");
   write_int(0, 20, 48, 0, &delta);
   write    (0, 0 , 56, 0, "GT");
   write_int(0, 20, 56, 0, &global_time);

   write    (0, 270, 0 , 0, "PX");
   write_int(0, 290, 0 , 0, &id_player.x);
   write    (0, 270, 8 , 0, "PY");
   write_int(0, 290, 8 , 0, &id_player.y);
   write    (0, 270, 16, 0, "PZ");
   write_int(0, 290, 16, 0, &id_player.z);
   write    (0, 270, 24, 0, "ANG");
   write_int(0, 290, 24, 0, &id_player.roll);

   write    (0, 270, 40, 0, "PVX");
   write_int(0, 290, 40, 0, &id_player.vx);
   write    (0, 270, 48, 0, "PVY");
   write_int(0, 290, 48, 0, &id_player.vy);
   write    (0, 270, 56, 0, "PVZ");
   write_int(0, 290, 56, 0, &id_player.vz);

   write    (0, 270, 72, 0, "BLK");
   write_int(0, 290, 72, 0, &level_rail.block);
   write    (0, 270, 80, 0, "CYC");
   write_int(0, 290, 80, 0, &level_rail.block_cycle);
   write    (0, 270, 88, 0, "B_A");
   write_int(0, 290, 88, 0, &level_rail.block_area);
   write    (0, 270, 96, 0, "AR");
   write_int(0, 290, 96, 0, &level_rail.area);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION log(STRING text);
//--------------------------------------------
BEGIN

   log_formatted(text, true);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION log_my_coords();
//--------------------------------------------
BEGIN

   log_formatted("Coords: "
                 + "(" + itoa(father.px) + ", "
                 + itoa(father.py) + ", "
                 + itoa(father.pz) + ")", true);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION log_formatted(STRING text, show_timestamp);
//--------------------------------------------
PRIVATE

   STRING line;

BEGIN

   IF (logging)
      IF (show_timestamp)
         line = itoa(timer);
         WHILE (strlen(line) < 8)
            line = "0" + line;
         END
         line = " [" + line + "] " + text;
      ELSE
         line = text;
      END
      system("echo " + line + " >> " + LOG_FILE);
   END

END
//--------------------------------------------

FUNCTION wait(delay)
PRIVATE
  timer_start;
BEGIN
  timer_start = timer[TIMER_GLOBAL];
  WHILE (timer[TIMER_GLOBAL] - timer_start < delay)
    FRAME;
  END
END

FUNCTION linear(r, p, a, b)
BEGIN
  RETURN ( (( (r - p) * a ) + ( p * b )) / r );
END

FUNCTION quadratic(r, p, a, b, c)
PRIVATE
  d, e;
BEGIN
  d = linear(r, p, a, b);
  e = linear(r, p, b, c);
  RETURN (linear(r, p, d, e));
END

FUNCTION cubic(r, p, a, b, c, d)
PRIVATE
  e, f;
BEGIN
  e = quadratic(r, p, a, b, c);
  f = quadratic(r, p, b, c, d);
  RETURN (linear(r, p, e, f));
END

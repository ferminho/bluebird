// -------------------------------------------
// BlueBird
// by Ferminho 2020
// done for DivCompo 2020 -- long live DIV!
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

   // Math and physics
   G_RES = 1000;        // GLOBAL RESOLUTION / precision to be used throughout all processes
   TRIGO_RES = 10;      // Resolution for trigonometry
   G_TO_TRIGO_DIV = 100;// From global to trigo resolution division (multiply if the other way around)

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
   ENTITY_ANGLE_STEP = 360000 / ENTITY_ANGLES;

   // Bird properties
   BIRD_SCALING = 15;   // %
   BIRD_2D_SIZE = 45;   // size of 2D sprite (ship itself, not container map)
   BIRD_HALF_2D_SIZE = BIRD_2D_SIZE / 2;
   BIRD_SLOW_SPEED = 225;
   BIRD_STD_SPEED = 450;
   BIRD_HIGH_SPEED = 675;
   BIRD_CLOSE_DISTANCE = 128;
   BIRD_STD_DISTANCE = 160;
   BIRD_LONG_DISTANCE = 192;
   BIRD_MAX_VEL = 400; // "2D" speed
   BIRD_MAIN_GRAPH = 1;

   // Other ship properties
   FEN_CAR_SCALING = 80;
   FEN_CAR_FRONT_GRAPH = 1;
   FEN_CAR_BACK_GRAPH = 1 + ENTITY_ANGLES;

   // Process priority
   PRIORITY_TIME_MASTER =     max_int;
   PRIORITY_PLAYER_INPUT =     100000;
   PRIORITY_RAIL_OPERATOR =     90000;
   PRIORITY_BIRD =               1000;
   PRIORITY_CAMERA =          -100000;

   // Mode8
   MAIN_M8 = 0;
   MAX_M8_COORD = 30208 * G_RES;
   M8_Z_OFFSET = 7;

   // Menu navigation
   MENU_QUIT = 0;
   MENU_START_GAME = 1;

   // Effects
   FADE_SPEED = 10; // standard fade speed for transitions

   // Input
   I_PLAYER = 0;

   // Action system
   ACTION_NONE = 0;
   // Camera actions
   ACTION_SPECTATE_PLAYER = 1;
   // Rail actions
   ACTION_ACTIVATE_RAIL = 2;

   // Level definition constants
   LEVEL_DEF_FILE = "levels.dat";
   LEVEL_MAX_LEVELS = 10;
   LEVEL_MAX_BLOCKS = 100;
   BLOCK_FLAG_REPEAT_WHILE_ENEMIES = 1; // obvious
   BLOCK_FLAG_FULL_CYCLES = 2;          // if repeating, never finish mid-cycle, always complete cycle

GLOBAL

   INT game_status; // current status, usually id of game status handler
   INT lev; // current level - name is unusually short for commodity

   // Levels definitions
   //    Since Div is not very fond of dynamic data structures, there are some "fixed big struct arrays".
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
      // World-related coords and dimensions, all in simple res
      STRUCT coords
         INT camera_z;
         INT area_width;
         INT area_height;
         INT area_gap;
         WORD area_x_abs_range[1];
         INT area_y_rel_range[1];
         WORD area_z_abs_range[1];
      END
      // Blocks definition include the sucession of areas, as well as enemy waves
      INT blocks_count;
      STRUCT blocks[LEVEL_MAX_BLOCKS]
         STRING areas; // areas in 2-digit space-delimited string (e.g. "00 12 01 01 03"), "" = empty block
         // watch out, do not add starting or trailing spaces. Don't or don't. There is no trim.
         INT flags;  // block properties, default 0
         STRING enemies; // enemy wave info in EDBBSL
      END
   END

   // Rail: info about the current "rail" the camera and player are following, in realtime
   STRUCT level_rail
      INT teleport_pxd, INT teleport_pyd; // (G_RES) teleport offset/delta during teleport frame
      // Coords
      INT px, INT py, INT pz; // (G_RES) updated every frame with base-px,py,pz
      INT x, INT y, INT z; // in simple res
      // Position within rail blocks defined in level
      // Block: current block
      // Block_cycle: current cycle withing block (0..n), i.e. number of times it has been repeated
      //    Makes sense only when a repeat-flag is active
      // Block_area: current area INDEX within block (first = 0, second = 1...)
      // Area: current area (area id, from 0 to n depending on grid size)
      INT block, INT block_cycle, INT block_area, INT area;
      // Limits of the flyable zone in G_RES
      INT min_y, INT max_y;
      INT min_z, INT max_z;
   END

   // World grid info
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
      INT x;         // -100 to 100
      INT y;         // -100 to 100
      INT throttle;  // -1 to 1
      fire;          // true or false
   END

   // Math
   INT psin[3599];
   INT pcos[3599];
   INT ptan[3599];
   INT half_hfov_tan; // tan of half the HFOV
   INT half_vfov_tan; // tan of half the VFOV

LOCAL

   // Game status process is binded to; it will be destroyed if game status changes
   INT binded_game_status;

   // Precision coordinates in G_RES resolution. This pz is meant for m8, not z-depth
   INT px, INT py, INT pz;

   // Roll angle (remember usual angle is yaw in m8)
   INT rangle;
   // Graph for entity angle 0 (first angle step)
   base_graph;

   // Velocity in units per second
   INT vx, INT vy, INT vz;

   // Action system
   action;

BEGIN

   init();

   orchestrator();

   let_me_alone();
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
   restore_type = SCREEN_RESTORE;
   dump_type = SCREEN_DUMP;
   set_fps(TARGET_FPS, MAX_FRAMESKIP);
   define_region(MAIN_REGION, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

   init_precalculated_trigonometry();
   time_master(); // this should always be running
   player_input(); // same goes for player input
END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME STATUS MANAGEMENT
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION orchestrator();
//--------------------------------------------
PRIVATE

   selection;

BEGIN

   fade(0, 0, 0, 64);

   display_logos();

   LOOP
      selection = show_menu();

      IF (selection == 0)
        RETURN;
      END
      IF (selection == 1)
         play_game();
      END
   END
END
//--------------------------------------------


//--------------------------------------------
FUNCTION display_logos();
//--------------------------------------------
BEGIN

   game_status = id;
   IF (SKIP_LOGOS)
      log("Skipped logos");
   ELSE
      // TODO: implement logos display
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION show_menu();
//--------------------------------------------
BEGIN

   game_status = id;
   IF (SKIP_MENU)
      log("Skipped menus");
   ELSE
      // TODO: implement menus
   END

   RETURN(1);
END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_game();
//--------------------------------------------
BEGIN

   play_intro();
   play_level(STARTING_LEVEL);

END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_intro();
//--------------------------------------------
BEGIN

   game_status = id;
   IF (SKIP_INTRO)
      log("Skipped intro");
   ELSE
      // TODO: implement intro
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_level(INT new_level);
//--------------------------------------------
BEGIN

   game_status = id;
   log("Playing level " + itoa(new_level));

   IF (levels[new_level].name == "")
      log("Level " + itoa(new_level) + " not defined. Returning");
      RETURN;
   END

   lev = new_level;
   // Common FPGs are loaded and re-processed each level to allow for multiple palettes
   // (for that, we'd need several pre-paletted FPGs though)
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
PRIVATE

   INT rel_min_y, INT rel_max_y;

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

   rel_min_y = levels[lev].coords.area_y_rel_range[0] * G_RES;
   rel_max_y = levels[lev].coords.area_y_rel_range[1] * G_RES;
   level_rail.min_y = py + rel_min_y;
   level_rail.max_y = py + rel_max_y;
   level_rail.min_z = levels[lev].coords.area_z_abs_range[0] * G_RES;
   level_rail.max_z = levels[lev].coords.area_z_abs_range[1] * G_RES;

   vx = BIRD_STD_SPEED;

   WHILE (game_status == binded_game_status)

      IF (action == ACTION_ACTIVATE_RAIL)
         px += vx * delta;

         IF (px >= grid.x1)
            // CHANGE AREA
            advance_rail_block_area();

            px += level_rail.teleport_pxd;
            py += level_rail.teleport_pyd;

            level_rail.min_y = py + rel_min_y;
            level_rail.max_y = py + rel_max_y;
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

   // calculate the map "grid" coords and dimensions
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
// This function knows about parsing block area definitions
PRIVATE

   STRING str;
   INT str_length;
   is_first_cycle, is_last_area, enemies_alive, flag_rwe, flag_fc;
   INT grid_i, INT grid_j; // position within grid matrix (i, j) i = row, j = col

BEGIN

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
         // Jump to next block
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
   str += " "; // one trailing space to make it multiple of 3 chars
   str_length = strlen(str);
   strdel(str, level_rail.block_area * 3, str_length - (level_rail.block_area * 3) - 2);
   level_rail.area = calculate(str);

   // Calculate target coords
   grid_j = level_rail.area / grid.rows;
   grid_i = level_rail.area MOD grid.rows;
   IF (grid_j >= grid.rows)
      log("ERROR: tried to jump to grid (" + itoa(grid_i) + ", " + itoa(grid_j) + ")");
      log("  Max: (" + itoa(grid.rows - 1) + ", " + itoa(grid.columns - 1) + ")");
      log("  Reading: block " + itoa(level_rail.block)
          + " block_area " + itoa(level_rail.block_area)
          + " area " + itoa(level_rail.area));
      exit("Grid jump out of range", -1);
   END
   x = grid.x0 + (grid_j * grid.cell_width); // in G_RES
   y = grid.y0 + (grid_i * grid.cell_height); // in G_RES

   // jump to the candidate block/area
   level_rail.teleport_pxd = x - level_rail.px;
   level_rail.teleport_pyd = y - level_rail.py;

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

   // all these to calculate the 3D-2D conversions and player positioning on screen
   INT player_dx;
   INT player_hres; // horiz resolution at player plane visible on screen (higher when farther)
   INT player_vres;
   INT player_ratio; // -1.0 to 1.0 on the rail_*_range (0.0 = center). In G_RES
   INT camera_max_pos; // temp var used to determine camera pos for player_*_ratio = 1.0

   INT target_y, INT target_z;

BEGIN

   rail_y_range = levels[lev].coords.area_y_rel_range[1]
             - levels[lev].coords.area_y_rel_range[0];
   half_rail_y_range = rail_y_range / 2;
   rail_z_range = levels[lev].coords.area_z_abs_range[1]
             - levels[lev].coords.area_z_abs_range[0];
   half_rail_z_range = rail_z_range / 2;
   rail_y_range += BIRD_2D_SIZE; // to include full ship in view
   rail_y_range *= G_RES;
   rail_z_range += BIRD_2D_SIZE + GROUND_MARGIN; // same and also let some margin to ground
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
   INT max_rangle;

BEGIN

   priority = PRIORITY_BIRD;
   binded_game_status = game_status;

   ctype = c_m8;
   file = fpg_bird;
   base_graph = BIRD_MAIN_GRAPH;

   py = level_rail.py;
   pz = level_rail.pz - BIRD_HALF_2D_SIZE;
   radius = BIRD_HALF_2D_SIZE;
   height = BIRD_2D_SIZE;

   WHILE (game_status == binded_game_status)

      px = level_rail.px + (BIRD_STD_DISTANCE * G_RES);
      py += level_rail.teleport_pyd;

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

      IF (py < level_rail.min_y) py = level_rail.min_y; vy = 0; END
      IF (py > level_rail.max_y) py = level_rail.max_y; vy = 0; END
      IF (pz < level_rail.min_z) pz = level_rail.min_z; vz = 0; END
      IF (pz > level_rail.max_z) pz = level_rail.max_z; vz = 0; END

      max_rangle = (100000 * vel_mod) / BIRD_MAX_VEL;
      rangle = rangle - (vy >> 1) * delta;
      rangle = clamp(rangle, -max_rangle, max_rangle + 10000);

      x = px / G_RES;
      y = py / G_RES;
      z = pz / G_RES;

      graph = get_entity_angle_graph(base_graph, rangle);
      FRAME;
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
   log("Loaded resources for level " + itoa(new_level));

   preprocess_resources();
   log("Preprocessed resources for level " + itoa(new_level));
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

   angle = angle MOD 360000;
   IF (angle < 0) angle+= 360000; END
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




// ----------------------------------------------------------
// ------------- SYSTEM & DEBUGGING
// ----------------------------------------------------------


//--------------------------------------------
PROCESS time_master();
//--------------------------------------------
PRIVATE

   INT last_timer = 0;
   INT carry_out = 0;  // remaining decimals from previous frame

BEGIN

   priority = PRIORITY_TIME_MASTER;

   LOOP
      delta = timer - last_timer;
      last_timer += delta;
      // transform delta to G_RES scale (not necessarily 1/100s as in timer[])
      delta = (delta * G_RES) / 100;

      // transform with speed, keeping carry out for next frame
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
   write_int(0, 290, 24, 0, &id_player.rangle);

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

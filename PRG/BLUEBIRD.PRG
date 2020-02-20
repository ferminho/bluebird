// -------------------------------------------
// BlueBird
// by Ferminho 2020
// done for DivCompo 2020 -- long live DIV!
//
// Licensed under> check LICENSE file
// -------------------------------------------


// Some notes about research I did:
// - Graph height impacts how m8 positions the graphic. Graph center does NOT
// - For a graph to be centered on screen it must be located at same Z as camera, but,
//    considering 0 height, m8_heights, etc, graph must be at camera.Z - (graph_height / 2) - 7.5
//    I haven't been able to fully understand why that 7.5. Must be related to perspective I guess but
//    it's not making 100% sense.


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
   TARGET_FPS = 120;
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
   CAMERA_ACCEL = 100;  // units / s^2
   MAX_CAMERA_VEL = 300;// units / s

   // Bird properties
   BIRD_2D_SIZE = 50;
   BIRD_HALF_2D_SIZE = BIRD_2D_SIZE / 2;
   BIRD_SLOW_SPEED = 225;
   BIRD_STD_SPEED = 450;
   BIRD_HIGH_SPEED = 675;
   BIRD_CLOSE_DISTANCE = 64;
   BIRD_STD_DISTANCE = 128;
   BIRD_LONG_DISTANCE = 192;

   // Process priority
   PRIORITY_TIME_MASTER =     max_int;
   PRIORITY_PLAYER_INPUT =     100000;
   PRIORITY_RAIL_OPERATOR =     90000;
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

   // Dynamic graph definitions
   ENTITY_ANGLES = 4;
   ENTITY_ANGLE_STEP = 360000 / ENTITY_ANGLES;
   PLAYER_SHIP_MAIN = 1;

   // Input
   I_PLAYER = 0;

   // Action system
   ACTION_NONE = 0;
   // Camera actions
   ACTION_SPECTATE_PLAYER = 1;
   // Rail actions
   ACTION_ACTIVATE_RAIL = 2;

GLOBAL

   INT game_status; // current status, usually id of game status handler

   // Levels
   INT current_level;

   STRUCT level_info[0] // all coords are resolution-1 based
      STRING name;
      STRING wld_path;
      STRING fpg_path;
      BYTE fog_color[2];
      BYTE fog_distance[1];
      INT camera_z;
      INT area_width;
      INT area_height;
      INT area_gap;
      WORD area_x_abs_range[1];
      INT area_y_rel_range[1];
      WORD area_z_abs_range[1];
   END =
         // --- LEVEL 0
         "Etherfax - Goliath Sea",  // Name
         "wld\bbst01.wld",          // WLD path
         "fpg\bbst01.fpg",          // FPG path
         15, 21, 23,                // Fog color
         10, 80,                    // Fog distance
         1650,                      // Camera Z
         14992, 5992, 8,            // Area width, height, gap among areas
         32, 7712,                  // Area X absolute range
         -150, 150,                 // Area Y relative range
         1500, 1800;                // Area Z absolute range

   STRUCT level_rail // info about the current "rail" the camera is following
      // All below is realtime info in G_RES units!
      INT teleport_pxd, INT teleport_pyd; // contains the teleport offset/delta during teleport frame
      INT px, INT py, INT pz; // updated every frame with base-px,py,pz not including camera offset
      // Limits of the flyable zone, updated realtime
      INT min_y, INT max_y;
      INT min_z, INT max_z;
   END

   // Resources: file res
   fpg_level;  // FPG handle of current level WLD
   fpg_ships;  // FPG handle of ships library
   wld_level;  // WLD handle of current level

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
      INT burn_x;    // -1 to 1
      INT burn_y;    // -1 to 1
      INT throttle;  // -1 to 1
      INT roll;      // -1 (CCW) to 1 (CW)
   END

   // Math
   WORD psin[3599];
   WORD pcos[3599];
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
FUNCTION play_level(INT level);
//--------------------------------------------
BEGIN

   game_status = id;
   log("Playing level " + itoa(level));

   current_level = level;
   load_level_resources(level);
   preprocess_angles(fpg_ships, 1, 2, 20);
   post_process();

   id_rail_operator = rail_operator();
   id_camera = camera();
   id_player = bird();

   start_mode8(id_camera, MAIN_M8, MAIN_REGION);
   set_env_color(level_info[level].fog_color[0],
                 level_info[level].fog_color[1],
                 level_info[level].fog_color[2]);
   set_fog(level_info[level].fog_distance[0],
           level_info[level].fog_distance[1]);

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
      input[I_PLAYER].burn_x       = 0;
      input[I_PLAYER].burn_y       = 0;
      input[I_PLAYER].throttle     = 0;
      input[I_PLAYER].roll         = 0;

      IF (key(_a)) input[I_PLAYER].x = -100; END
      IF (key(_d)) input[I_PLAYER].x = 100; END
      IF (key(_w)) input[I_PLAYER].y = 100; END
      IF (key(_s)) input[I_PLAYER].y = -100; END

      FRAME;
   END

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME ENTITIES
// ----------------------------------------------------------


//--------------------------------------------
PROCESS rail_operator();
//--------------------------------------------
PRIVATE

   INT area_w, INT area_h, INT area_gap, INT area_x0, INT area_x1;

   INT grid_x0;
   INT grid_y0;
   INT grid_x1;
   INT grid_cell_width;
   INT grid_cell_height;
   INT grid_rows;
   INT grid_columns;

   INT rel_min_y, INT rel_max_y;

BEGIN

   binded_game_status = game_status;
   priority = PRIORITY_RAIL_OPERATOR;

   // cache values in shorter variables
   area_w = level_info[current_level].area_width;
   area_h = level_info[current_level].area_height;
   area_gap = level_info[current_level].area_gap;
   area_x0 = level_info[current_level].area_x_abs_range[0];
   area_x1 = level_info[current_level].area_x_abs_range[1];

   // calculate the map "grid" coords and dimensions
   grid_x0 = area_x0 * G_RES;
   grid_y0 = (area_h * G_RES) / 2;
   grid_x1 = area_x1 * G_RES;
   grid_cell_width = (area_w + area_gap) * G_RES;
   grid_cell_height = (area_h + area_gap) * G_RES;
   grid_rows = MAX_M8_COORD / grid_cell_height;
   grid_columns = MAX_M8_COORD / grid_cell_width;

   px = grid_x0;
   py = grid_y0;
   pz = level_info[current_level].camera_z * G_RES;

   level_rail.px = px;
   level_rail.py = py;
   level_rail.pz = pz;

   rel_min_y = level_info[current_level].area_y_rel_range[0] * G_RES;
   rel_max_y = level_info[current_level].area_y_rel_range[1] * G_RES;
   level_rail.min_y = level_rail.py + rel_min_y;
   level_rail.max_y = level_rail.py + rel_max_y;
   level_rail.min_z = level_info[current_level].area_z_abs_range[0] * G_RES;
   level_rail.max_z = level_info[current_level].area_z_abs_range[1] * G_RES;


   vx = BIRD_STD_SPEED;

   WHILE (game_status == binded_game_status)

      IF (action == ACTION_ACTIVATE_RAIL)
         px += vx * delta;

         IF (px >= grid_x1)
            // CHANGE AREA
            level_rail.teleport_pxd = -(grid_x1 - grid_x0);
            level_rail.teleport_pyd = 0;

            px += level_rail.teleport_pxd;
            py += level_rail.teleport_pyd;

            level_rail.py += level_rail.teleport_pyd;
            level_rail.min_y = level_rail.py + rel_min_y;
            level_rail.max_y = level_rail.py + rel_max_y;
         ELSE
            level_rail.teleport_pxd = 0;
            level_rail.teleport_pyd = 0;
         END
      END

      level_rail.px = px;

      FRAME;
   END

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

   rail_y_range = level_info[current_level].area_y_rel_range[1]
             - level_info[current_level].area_y_rel_range[0];
   half_rail_y_range = rail_y_range / 2;
   rail_z_range = level_info[current_level].area_z_abs_range[1]
             - level_info[current_level].area_z_abs_range[0];
   half_rail_z_range = rail_z_range / 2;
   rail_y_range += BIRD_2D_SIZE; // to include full ship in view
   rail_y_range *= G_RES;
   rail_z_range += BIRD_2D_SIZE; // to include full ship in view
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
      target_y = level_rail.py;
      target_z = level_rail.pz;

      IF (action == ACTION_SPECTATE_PLAYER)
         player_dx = (id_player.px - level_rail.px) / G_RES;
         player_hres = player_dx * 2 * half_hfov_tan;
         player_vres = player_dx * 2 * half_vfov_tan;

         IF (player_hres < rail_y_range)
            player_ratio = (id_player.py + 500 - level_rail.py) / half_rail_y_range;
            camera_max_pos = (rail_y_range - player_hres) / 2;
            target_y += (camera_max_pos / G_RES) * player_ratio;
         END

         IF (player_vres < rail_z_range)
            player_ratio = id_player.pz + 500 + BIRD_HALF_2D_SIZE * G_RES; // position correction
            player_ratio = (player_ratio - level_rail.pz) / half_rail_z_range;
            camera_max_pos = (rail_z_range - player_vres) / 2;
            target_z += ((camera_max_pos / G_RES) * player_ratio);
         END
      END

      // smooth approximation
      py = (target_y * 25 + py * 75) / 100;
      pz = (target_z * 25 + pz * 75) / 100;

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
BEGIN

   binded_game_status = game_status;

   ctype = c_m8;
   file = fpg_ships;
   base_graph = 2;

   py = level_rail.py;
   pz = level_rail.pz;
   radius = BIRD_HALF_2D_SIZE;
   height = BIRD_2D_SIZE;

   WHILE (game_status == binded_game_status)

      px = level_rail.px + (BIRD_STD_DISTANCE * G_RES);

      vy += (input[I_PLAYER].x * delta) / G_RES;
      vz += (input[I_PLAYER].y * delta) / G_RES;

      py += vy * delta;
      pz += vz * delta;

      IF (py < level_rail.min_y) py = level_rail.min_y; vy = 0; END
      IF (py > level_rail.max_y) py = level_rail.max_y; vy = 0; END
      IF (pz < level_rail.min_z) pz = level_rail.min_z; vz = 0; END
      IF (pz > level_rail.max_z) pz = level_rail.max_z; vz = 0; END

      x = px / G_RES;
      y = py / G_RES;
      z = pz / G_RES;
      graph = get_entity_angle_graph(base_graph, rangle);
      FRAME;
   END

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- RESOURCE MANAGEMENT
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION load_level_resources(INT level);
//--------------------------------------------
BEGIN

   load_pal(BASE_PATH + level_info[level].fpg_path);
   fpg_level = load_fpg(BASE_PATH + level_info[level].fpg_path);
   wld_level = load_wld(BASE_PATH + level_info[level].wld_path, fpg_level);
   fpg_ships = load_fpg(BASE_PATH + "fpg\ships.fpg");
   log("Loaded resources for level " + itoa(level));

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

   write    (0, 270, 0 , 0, "PX");
   write_int(0, 290, 0 , 0, &id_player.x);
   write    (0, 270, 8 , 0, "PY");
   write_int(0, 290, 8 , 0, &id_player.y);
   write    (0, 270, 16, 0, "PZ");
   write_int(0, 290, 16, 0, &id_player.z);

   write    (0, 270, 24 , 0, "PVX");
   write_int(0, 290, 24, 0, &id_player.vx);
   write    (0, 270, 32, 0, "PVY");
   write_int(0, 290, 32, 0, &id_player.vy);
   write    (0, 270, 40, 0, "PVZ");
   write_int(0, 290, 40, 0, &id_player.vz);


   write    (0, 0 , 32, 0, "FPS");
   write_int(0, 20, 32, 0, &fps);
   write    (0, 0 , 40, 0, "TS");
   write_int(0, 20, 40, 0, &time_speed);
   write    (0, 0 , 48, 0, "d");
   write_int(0, 20, 48, 0, &delta);
   write    (0, 0 , 56, 0, "GT");
   write_int(0, 20, 56, 0, &global_time);

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

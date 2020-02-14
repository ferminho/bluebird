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
   TARGET_FPS = 60;
   MAX_FRAMESKIP = 2;
   MAIN_REGION = 1;

   // Game logic
   G_RES = 1000;        // GLOBAL RESOLUTION / precision to be used throughout all processes
   BIRD_SLOW_SPEED = 225;
   BIRD_STD_SPEED = 450;
   BIRD_HIGH_SPEED = 675;
   BIRD_CLOSE_DISTANCE = 64;
   BIRD_STD_DISTANCE = 128;
   BIRD_LONG_DISTANCE = 192;

   // Process priority
   PRIORITY_TIME_MASTER = max_int;
   PRIORITY_PLAYER_INPUT = max_int - 1;
   PRIORITY_CAMERA = max_int - 2;

   // Mode8
   MAIN_M8 = 0;
   MAX_M8_COORD = 30208 * G_RES;

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
      INT sector_width;
      INT sector_height;
      INT sector_gap;
      WORD sector_x_range[1];
   END =
         // --- LEVEL 0
         "Etherfax - Goliath Sea",  // Name
         "wld\bbst01.wld",          // WLD path
         "fpg\bbst01.fpg",          // FPG path
         15, 21, 23,                // Fog color
         10, 80,                    // Fog distance
         1600,                      // Camera Z
         14992, 5992, 8,            // Sector width, height, gap among sectors
         32, 7712;                  // Sector X range (playable zone)

   // Resources: file res
   fpg_level;  // FPG handle of current level WLD
   fpg_ships;  // FPG handle of ships library
   wld_level;  // WLD handle of current level

   // Important processes
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

LOCAL

   // game status process is binded to; it will be destroyed if game status changes
   INT binded_game_status;

   // precision coordinates in G_RES resolution. This pz is meant for m8, not z-depth
   INT px, INT py, INT pz;

   // roll angle (remember usual angle is yaw in m8)
   INT rangle;
   // graph for entity angle 0 (first angle step)
   base_graph;

   // velocity in units per second
   INT vx, vy;

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
PROCESS camera();
//--------------------------------------------
PRIVATE

   INT sector_w, INT sector_h, INT sector_gap, INT sector_x0, INT sector_x1;

   INT grid_x0;
   INT grid_y0;
   INT grid_x1;
   INT grid_cell_width;
   INT grid_cell_height;
   INT grid_rows;
   INT grid_columns;

BEGIN

   binded_game_status = game_status;
   ctype = c_m8;
   priority = PRIORITY_CAMERA;

   // cache values in shorter variables
   sector_w = level_info[current_level].sector_width;
   sector_h = level_info[current_level].sector_height;
   sector_gap = level_info[current_level].sector_gap;
   sector_x0 = level_info[current_level].sector_x_range[0];
   sector_x1 = level_info[current_level].sector_x_range[1];

   // calculate the map "grid" coords and dimensions
   grid_x0 = sector_x0 * G_RES;
   grid_y0 = (sector_h * G_RES) / 2;
   grid_x1 = sector_x1 * G_RES;
   grid_cell_width = (sector_w + sector_gap) * G_RES;
   grid_cell_height = (sector_h + sector_gap) * G_RES;
   grid_rows = MAX_M8_COORD / grid_cell_height;
   grid_columns = MAX_M8_COORD / grid_cell_width;

   px = grid_x0;
   py = grid_y0;
   pz = level_info[current_level].camera_z * G_RES;
   radius = 0;
   height = 0;
   m8.height = 0;

   vx = BIRD_STD_SPEED;
   size=500;

   WHILE (game_status == binded_game_status)
      IF (DEVELOPER_MODE)
         IF (key(_j)) py -= 50 * delta; END
         IF (key(_l)) py += 50 * delta; END
         IF (key(_i)) pz += 50 * delta; END
         IF (key(_k)) pz -= 50 * delta; END
      END

      px += vx * delta;

      IF (px >= grid_x1)
         px -= (grid_x1 - grid_x0);
      END

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
   py = id_camera.py;
   radius = 0;
   height = 0;
   pz = level_info[current_level].camera_z * G_RES;

   WHILE (game_status == binded_game_status)

      px = id_camera.px + (BIRD_STD_DISTANCE * G_RES);

      py += input[I_PLAYER].x * delta;
      pz += input[I_PLAYER].y * delta;

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

   write    (0, 0 , 0 , 0, "X");
   write_int(0, 20, 0 , 0, &id_camera.x);
   write    (0, 0 , 8 , 0, "Y");
   write_int(0, 20, 8 , 0, &id_camera.y);
   write    (0, 0 , 16, 0, "Z");
   write_int(0, 20, 16, 0, &id_camera.z);

   write    (0, 270, 0 , 0, "X");
   write_int(0, 290, 0 , 0, &id_player.x);
   write    (0, 270, 8 , 0, "Y");
   write_int(0, 290, 8 , 0, &id_player.y);
   write    (0, 270, 16, 0, "Z");
   write_int(0, 290, 16, 0, &id_player.z);


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

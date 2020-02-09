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

   // Start config
   STARTING_LEVEL = 0;
   SKIP_LOGOS = true;
   SKIP_MENU = true;
   SKIP_INTRO = true;

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
   G_RES = 1000; // GLOBAL RESOLUTION / precision to be used throughout all processes

   // Mode8
   MAIN_M8 = 0;
   MAX_M8_COORD = 30208 * G_RES;

   // Menu navigation
   MENU_QUIT = 0;
   MENU_START_GAME = 1;

   // Effects
   FADE_SPEED = 10; // standard fade speed for transitions

GLOBAL

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
   END =
      "Etherfax - Goliath Sea",   // Name
      "bluebird\wld\bbst01.wld",  // WLD path
      "bluebird\fpg\bbst01.fpg",  // FPG path
      15, 21, 23,                 // Fog color
      20, 75,                     // Fog distance
      1580,                       // Camera Z
      14992, 5992, 8;             // Sector width, height & gap among sectors

   // Resources
   fpg_level;  // FPG handle of current level WLD
   wld_level;  // WLD handle of current level

   // Important processes
   id_camera;
   id_player;

LOCAL

   INT px, INT py, INT pz;

BEGIN

  init();

  orchestrator();

  let_me_alone();

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- GAME STATUS MANAGEMENT
// ----------------------------------------------------------


//--------------------------------------------
FUNCTION init();
//--------------------------------------------
BEGIN

   set_mode(SCREEN_RES);
   restore_type = SCREEN_RESTORE;
   dump_type = SCREEN_DUMP;
   set_fps(TARGET_FPS, MAX_FRAMESKIP);
   define_region(MAIN_REGION, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

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

   IF (!SKIP_LOGOS)
      // TODO: implement logos display
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION show_menu();
//--------------------------------------------
BEGIN

   IF (!SKIP_MENU)
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

   IF (!SKIP_INTRO)
      // TODO: implement intro
   END

END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_level(INT level);
//--------------------------------------------
BEGIN

   current_level = level;
   load_level_resources(level);

   id_camera = camera();

   start_mode8(id_camera, MAIN_M8, MAIN_REGION);
     // BYTE fog_color[2];
     // BYTE fog_distance[1];
   set_env_color(level_info[level].fog_color[0],
                 level_info[level].fog_color[1],
                 level_info[level].fog_color[2]);
   set_fog(level_info[level].fog_distance[0],
           level_info[level].fog_distance[1]);

   fade_and_wait(100, 100, 100, FADE_SPEED);

   LOOP
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

   INT sector_width;
   INT sector_height;
   INT sector_gap;

   INT grid_x0;
   INT grid_y0;
   INT grid_cell_width;
   INT grid_cell_height;
   INT grid_rows;
   INT grid_columns;

BEGIN

   ctype = c_m8;

   sector_width = level_info[current_level].sector_width;
   sector_height = level_info[current_level].sector_height;
   sector_gap = level_info[current_level].sector_gap;

   grid_x0 = 32 * G_RES;
   grid_y0 = (sector_height * G_RES) / 2;
   grid_cell_width = (sector_width + sector_gap) * G_RES;
   grid_cell_height = (sector_height + sector_gap) * G_RES;
   grid_rows = MAX_M8_COORD / grid_cell_height;
   grid_columns = MAX_M8_COORD / grid_cell_width;

   write_int(0,0,0,0,&x);
   write_int(0,0,8,0,&y);
   write_int(0,0,16,0,&z);

   px = grid_x0;
   py = grid_y0;
   pz = level_info[current_level].camera_z * G_RES;
   height = 8;
   radius = 8;
   m8.height = 0;

   LOOP

      x = px / G_RES;
      y = py / G_RES;
      z = pz / G_RES;
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

   fpg_level = load_fpg(level_info[level].fpg_path);
   wld_level = load_wld(level_info[level].wld_path, fpg_level);

END
//--------------------------------------------


// ----------------------------------------------------------
// ------------- VISUAL EFFECTS
// ----------------------------------------------------------


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

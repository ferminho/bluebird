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

   // Start config (dev utils)
   STARTING_LEVEL = 0;
   SKIP_LOGOS = true;
   SKIP_MENU = true;
   SKIP_INTRO = true;

   // Menu navigation
   MENU_QUIT = 0;
   MENU_START_GAME = 1;

GLOBAL

   STRUCT level_info[0]
      STRING name;
      STRING wld_path;
      STRING fpg_path;
      BYTE fog_color[2];
      BYTE fog_distance[1];
   END =
      "Etherfax - Goliath Sea",   // Name
      "bluebird\wld\bbst01.wld",  // WLD path
      "bluebird\fpg\bbst01.fpg",  // FPG path
      15, 21, 23,                 // Fog color
      20, 75;                     // Fog distance

LOCAL

BEGIN

  orchestrator();

  let_me_alone();

END
//--------------------------------------------


//--------------------------------------------
FUNCTION orchestrator();
//--------------------------------------------

PRIVATE

   selection;

BEGIN

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

   IF (SKIP_LOGOS)
      RETURN;
   END

   // TODO: implement logos display
END
//--------------------------------------------


//--------------------------------------------
FUNCTION show_menu();
//--------------------------------------------

BEGIN

   IF (SKIP_MENU)
      RETURN;
   END

   // TODO: implement menus
END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_game();
//--------------------------------------------

BEGIN

   play_intro();

   // TODO: implement game
END
//--------------------------------------------


//--------------------------------------------
FUNCTION play_intro();
//--------------------------------------------

BEGIN

   IF (SKIP_INTRO)
      RETURN;
   END

   // TODO: implement intro
END
//--------------------------------------------


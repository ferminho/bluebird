// -------------------------------------------
// BlueBird - Leveler utility
// by Ferminho 2020
// done for DivCompo 2020 -- long live DIV!
//
// Licensed under> check LICENSE file
// -------------------------------------------


// IMPORTANT: keep CONST & GLOBAL in sync with BLUEBIRD.PRG!!
PROGRAM leveler;
CONST
   BASE_PATH = "ferminho\bluebird\";
   // Level definition constants
   LEVEL_DEF_FILE = "levels.dat";
   LEVEL_MAX_LEVELS = 4;
   LEVEL_MAX_BLOCKS = 80;
   BLOCK_FLAG_CYCLE_WHILE_ENEMIES = 1;

GLOBAL
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
         STRING enemies; // enemy wave info in BBEWML
      END
   END

LOCAL
   STRUCT POINTER levels lev;
   INT i;

BEGIN
   init_levels();
   save(BASE_PATH + "levels.dat", &levels, sizeof(levels));
END

///////////////////////////////////////////////////////////////////////////////////
FUNCTION init_levels()
BEGIN
   init_level0();
   init_level1();
END

/////////////////////////////////////////// LEVEL 0
FUNCTION init_level0()
BEGIN
   lev = &levels[0];
   lev.name = "Etherfax - Goliath Sea";
   // RES
   lev.res.wld_path = "wld\bbst01.wld";
   lev.res.fpg_path = "fpg\bbst01.fpg";
   // VISUALS
   set_fog_info(lev, 6, 5, 17, 10, 80);
   // COORDS
   lev.coords.camera_z = 1700;
   set_area_dimensions(lev, 9992, 5880, 8);
   set_area_ranges(lev, 32, 6432, -350, 350, 1500, 1900);
   // BLOCKS
   // 000
   lev.blocks[i].areas = "01";
   lev.blocks[i].enemies = "";
   i += 1;
   lev.blocks[i].areas = "00 01 00 00 01";
   lev.blocks[i].enemies = "";

   set_block_count(lev);
END

/////////////////////////////////////////// LEVEL 1
FUNCTION init_level1()
BEGIN
   lev = &levels[1];
END


///////////////////////////////////////////////////////////////////////////////////
FUNCTION set_fog_info(STRUCT POINTER levels ptr,
                      BYTE r64, BYTE g64, BYTE b64,
                      BYTE init_dist, BYTE end_dist)
BEGIN
   ptr.visual.fog_color[0] = (r64 * 100) / 64;
   ptr.visual.fog_color[1] = (g64 * 100) / 64;
   ptr.visual.fog_color[2] = (b64 * 100) / 64;
   ptr.visual.fog_distance[0] = init_dist;
   ptr.visual.fog_distance[1] = end_dist;
END
///////////////////////////////////////////////////////////////////////////////////
FUNCTION set_area_dimensions(STRUCT POINTER levels ptr,
                             INT width, INT height, INT gap)
BEGIN
   ptr.coords.area_width = width;
   ptr.coords.area_height = height;
   ptr.coords.area_gap = gap;
END
///////////////////////////////////////////////////////////////////////////////////
FUNCTION set_area_ranges(STRUCT POINTER levels ptr,
                         INT abs_x0, INT abs_x1,
                         INT rel_y0, INT rel_y1,
                         INT abs_z0, INT abs_z1)
BEGIN
   ptr.coords.area_x_abs_range[0] = abs_x0;
   ptr.coords.area_x_abs_range[1] = abs_x1;
   ptr.coords.area_y_rel_range[0] = rel_y0;
   ptr.coords.area_y_rel_range[1] = rel_y1;
   ptr.coords.area_z_abs_range[0] = abs_z0;
   ptr.coords.area_z_abs_range[1] = abs_z1;
END
///////////////////////////////////////////////////////////////////////////////////
FUNCTION set_block_count(STRUCT POINTER levels ptr)
BEGIN
   WHILE (i < LEVEL_MAX_BLOCKS AND ptr.blocks[i].areas != "")
      i += 1;
   END
   ptr.blocks_count = i;
END
///////////////////////////////////////////////////////////////////////////////////
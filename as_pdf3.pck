CREATE OR REPLACE PACKAGE as_pdf3 IS
  /**********************************************
  **
  ** Additional comment by Andreas Weiden:
  **AS_PDF3_MOD
  
  ** The following methods were added by me for additinal functionality needed for PK_JRXML_REPGEN
  **
  ** -   PR_GOTO_PAGE
  ** -   PR_GOTO_CURRENT_PAGE;
  ** -   PR_LINE
  ** -   PR_POLYGON
  ** -   PR_PATH
  **
  ** Changed in parameter p_txt for procedure raw2page  from blob to raw
  ** Added global collection g_settings_per_tab to store different pageformat for each page. 
  ** changed add_page to write a MediaBox-entry with the g_settings_per_tab-content for each page
  **
  ** Change in subset_font:Checking for raw-length reduced from 32778 to 32000 because of raw-length-error
  ** in specific cases
  **
  ** Various changes for font-usage: The access to g_fonts(g_current_font) is very slow, replaced it with a specific font-record
  ** which is filled when g_current_font changes
  **
  ** Changes in adler32: The num-value of a hex-byte is no longer calculated by a to_number, but taken from an associative array
  ** done for preformance
  **
  ** Changes in put_image_methods: the adler32-value can be provided from outside
  ***/

  /**********************************************
  **
  ** Author: Anton Scheffer
  ** Date: 11-04-2012
  ** Website: http://technology.amis.nl
  ** See also: http://technology.amis.nl/?p=17718
  **
  ** Changelog:
  **   Date: 16-04-2012
  **     changed code for parse_png
  **   Date: 15-04-2012
  **     only dbms_lob.freetemporary for temporary blobs
  **   Date: 11-04-2012
  **     Initial release of as_pdf3
  **
  ******************************************************************************
  ******************************************************************************
  Copyright (C) 2012 by Anton Scheffer
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  
  ******************************************************************************
  ******************************************** */
  --
  c_get_page_width    CONSTANT PLS_INTEGER := 0;
  c_get_page_height   CONSTANT PLS_INTEGER := 1;
  c_get_margin_top    CONSTANT PLS_INTEGER := 2;
  c_get_margin_right  CONSTANT PLS_INTEGER := 3;
  c_get_margin_bottom CONSTANT PLS_INTEGER := 4;
  c_get_margin_left   CONSTANT PLS_INTEGER := 5;
  c_get_x             CONSTANT PLS_INTEGER := 6;
  c_get_y             CONSTANT PLS_INTEGER := 7;
  c_get_fontsize      CONSTANT PLS_INTEGER := 8;
  c_get_current_font  CONSTANT PLS_INTEGER := 9;

  TYPE tVertices IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

  PATH_MOVE_TO  CONSTANT NUMBER := 1;
  PATH_LINE_TO  CONSTANT NUMBER := 2;
  PATH_CURVE_TO CONSTANT NUMBER := 3;
  PATH_CLOSE    CONSTANT NUMBER := 4;

  TYPE tPathElement IS RECORD(
    nType NUMBER,
    nVal1 NUMBER,
    nVal2 NUMBER,
    nVal3 NUMBER,
    nVal4 NUMBER,
    nVal5 NUMBER,
    nVal6 NUMBER);

  TYPE tPath IS TABLE OF tPathElement INDEX BY BINARY_INTEGER;
  --
  FUNCTION file2blob(p_dir       VARCHAR2,
                     p_file_name VARCHAR2) RETURN BLOB;
  --
  FUNCTION conv2uu(p_value NUMBER,
                   p_unit  VARCHAR2) RETURN NUMBER;
  --
  PROCEDURE set_page_size(p_width  NUMBER,
                          p_height NUMBER,
                          p_unit   VARCHAR2 := 'cm');
  --
  PROCEDURE set_page_format(p_format VARCHAR2 := 'A4');
  --
  PROCEDURE set_page_orientation(p_orientation VARCHAR2 := 'PORTRAIT');
  --
  PROCEDURE set_margins(p_top    NUMBER := NULL,
                        p_left   NUMBER := NULL,
                        p_bottom NUMBER := NULL,
                        p_right  NUMBER := NULL,
                        p_unit   VARCHAR2 := 'cm');
  --
  PROCEDURE set_info(p_title    VARCHAR2 := NULL,
                     p_author   VARCHAR2 := NULL,
                     p_subject  VARCHAR2 := NULL,
                     p_keywords VARCHAR2 := NULL);
  --
  PROCEDURE init;
  --
  FUNCTION get_pdf RETURN BLOB;
  --
  PROCEDURE save_pdf(p_dir      VARCHAR2 := 'MY_DIR',
                     p_filename VARCHAR2 := 'my.pdf',
                     p_freeblob BOOLEAN := TRUE);
  --
  PROCEDURE txt2page(p_txt VARCHAR2);
  --
  PROCEDURE put_txt(p_x                NUMBER,
                    p_y                NUMBER,
                    p_txt              VARCHAR2,
                    p_degrees_rotation NUMBER := NULL);
  --
  FUNCTION str_len(p_txt VARCHAR2) RETURN NUMBER;
  --
  PROCEDURE WRITE(p_txt         IN VARCHAR2,
                  p_x           IN NUMBER := NULL,
                  p_y           IN NUMBER := NULL,
                  p_line_height IN NUMBER := NULL,
                  p_start       IN NUMBER := NULL -- left side of the available text box
                 ,
                  p_width       IN NUMBER := NULL -- width of the available text box
                 ,
                  p_alignment   IN VARCHAR2 := NULL);
  --
  PROCEDURE set_font(p_index         PLS_INTEGER,
                     p_fontsize_pt   NUMBER,
                     p_output_to_doc BOOLEAN := TRUE);
  --
  FUNCTION set_font(p_fontname      VARCHAR2,
                    p_fontsize_pt   NUMBER,
                    p_output_to_doc BOOLEAN := TRUE) RETURN PLS_INTEGER;
  --
  PROCEDURE set_font(p_fontname      VARCHAR2,
                     p_fontsize_pt   NUMBER,
                     p_output_to_doc BOOLEAN := TRUE);
  --
  FUNCTION set_font(p_family        VARCHAR2,
                    p_style         VARCHAR2 := 'N',
                    p_fontsize_pt   NUMBER := NULL,
                    p_output_to_doc BOOLEAN := TRUE) RETURN PLS_INTEGER;
  --
  PROCEDURE set_font(p_family        VARCHAR2,
                     p_style         VARCHAR2 := 'N',
                     p_fontsize_pt   NUMBER := NULL,
                     p_output_to_doc BOOLEAN := TRUE);
  --
  PROCEDURE new_page;
  --
  FUNCTION load_ttf_font(p_font     BLOB,
                         p_encoding VARCHAR2 := 'WINDOWS-1252',
                         p_embed    BOOLEAN := FALSE,
                         p_compress BOOLEAN := TRUE,
                         p_offset   NUMBER := 1) RETURN PLS_INTEGER;
  --
  PROCEDURE load_ttf_font(p_font     BLOB,
                          p_encoding VARCHAR2 := 'WINDOWS-1252',
                          p_embed    BOOLEAN := FALSE,
                          p_compress BOOLEAN := TRUE,
                          p_offset   NUMBER := 1);
  --
  FUNCTION load_ttf_font(p_dir      VARCHAR2 := 'MY_FONTS',
                         p_filename VARCHAR2 := 'BAUHS93.TTF',
                         p_encoding VARCHAR2 := 'WINDOWS-1252',
                         p_embed    BOOLEAN := FALSE,
                         p_compress BOOLEAN := TRUE) RETURN PLS_INTEGER;
  --
  PROCEDURE load_ttf_font(p_dir      VARCHAR2 := 'MY_FONTS',
                          p_filename VARCHAR2 := 'BAUHS93.TTF',
                          p_encoding VARCHAR2 := 'WINDOWS-1252',
                          p_embed    BOOLEAN := FALSE,
                          p_compress BOOLEAN := TRUE);
  --
  PROCEDURE load_ttc_fonts(p_ttc      BLOB,
                           p_encoding VARCHAR2 := 'WINDOWS-1252',
                           p_embed    BOOLEAN := FALSE,
                           p_compress BOOLEAN := TRUE);
  --
  PROCEDURE load_ttc_fonts(p_dir      VARCHAR2 := 'MY_FONTS',
                           p_filename VARCHAR2 := 'CAMBRIA.TTC',
                           p_encoding VARCHAR2 := 'WINDOWS-1252',
                           p_embed    BOOLEAN := FALSE,
                           p_compress BOOLEAN := TRUE);
  --
  PROCEDURE set_color(p_rgb VARCHAR2 := '000000');
  --
  PROCEDURE set_color(p_red   NUMBER := 0,
                      p_green NUMBER := 0,
                      p_blue  NUMBER := 0);
  --
  PROCEDURE set_bk_color(p_rgb VARCHAR2 := 'ffffff');
  --
  PROCEDURE set_bk_color(p_red   NUMBER := 0,
                         p_green NUMBER := 0,
                         p_blue  NUMBER := 0);
  --
  PROCEDURE horizontal_line(p_x          IN NUMBER,
                            p_y          IN NUMBER,
                            p_width      IN NUMBER,
                            p_line_width IN NUMBER := 0.5,
                            p_line_color IN VARCHAR2 := '000000');
  --
  PROCEDURE vertical_line(p_x          IN NUMBER,
                          p_y          IN NUMBER,
                          p_height     IN NUMBER,
                          p_line_width IN NUMBER := 0.5,
                          p_line_color IN VARCHAR2 := '000000');
  --
  PROCEDURE rect(p_x          IN NUMBER,
                 p_y          IN NUMBER,
                 p_width      IN NUMBER,
                 p_height     IN NUMBER,
                 p_line_color IN VARCHAR2 := NULL,
                 p_fill_color IN VARCHAR2 := NULL,
                 p_line_width IN NUMBER := 0.5);
  --
  FUNCTION get(p_what IN PLS_INTEGER) RETURN NUMBER;
  --
  PROCEDURE put_image(p_img     BLOB,
                      p_x       NUMBER,
                      p_y       NUMBER,
                      p_width   NUMBER := NULL,
                      p_height  NUMBER := NULL,
                      p_align   VARCHAR2 := 'center',
                      p_valign  VARCHAR2 := 'top',
                      p_adler32 VARCHAR2 := NULL);
  --
  PROCEDURE put_image(p_dir       VARCHAR2,
                      p_file_name VARCHAR2,
                      p_x         NUMBER,
                      p_y         NUMBER,
                      p_width     NUMBER := NULL,
                      p_height    NUMBER := NULL,
                      p_align     VARCHAR2 := 'center',
                      p_valign    VARCHAR2 := 'top',
                      p_adler32   VARCHAR2 := NULL);
  --
  PROCEDURE put_image(p_url     VARCHAR2,
                      p_x       NUMBER,
                      p_y       NUMBER,
                      p_width   NUMBER := NULL,
                      p_height  NUMBER := NULL,
                      p_align   VARCHAR2 := 'center',
                      p_valign  VARCHAR2 := 'top',
                      p_adler32 VARCHAR2 := NULL);
  --
  PROCEDURE set_page_proc(p_src CLOB);
  --
  TYPE tp_col_widths IS TABLE OF NUMBER;
  TYPE tp_headers IS TABLE OF VARCHAR2(32767);
  --
  PROCEDURE query2table(p_query   VARCHAR2,
                        p_widths  tp_col_widths := NULL,
                        p_headers tp_headers := NULL);
  --

  PROCEDURE PR_GOTO_PAGE(i_nPage IN NUMBER);

  PROCEDURE PR_GOTO_CURRENT_PAGE;

  PROCEDURE PR_LINE(i_nX1         IN NUMBER,
                    i_nY1         IN NUMBER,
                    i_nX2         IN NUMBER,
                    i_nY2         IN NUMBER,
                    i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                    i_nLineWidth  IN NUMBER DEFAULT 0.5,
                    i_vcStroke    IN VARCHAR2 DEFAULT NULL);

  PROCEDURE PR_POLYGON(i_lXs         IN tVertices,
                       i_lYs         IN tVertices,
                       i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                       i_vcFillColor IN VARCHAR2 DEFAULT NULL,
                       i_nLineWidth  IN NUMBER DEFAULT 0.5);

  PROCEDURE PR_PATH(i_lPath       IN tPath,
                    i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                    i_vcFillColor IN VARCHAR2 DEFAULT NULL,
                    i_nLineWidth  IN NUMBER DEFAULT 0.5);

  FUNCTION adler32(p_src IN BLOB) RETURN VARCHAR2;

  $IF not DBMS_DB_VERSION.VER_LE_10 $THEN
  PROCEDURE refcursor2table(p_rc      SYS_REFCURSOR,
                            p_widths  tp_col_widths := NULL,
                            p_headers tp_headers := NULL);
  --
$END
END;
/
CREATE OR REPLACE PACKAGE BODY as_pdf3 IS
  --
  TYPE tHex IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(2);

  lHex tHex;

  TYPE tp_pls_tab IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
  TYPE tp_objects_tab IS TABLE OF NUMBER(10) INDEX BY PLS_INTEGER;
  TYPE tp_pages_tab IS TABLE OF BLOB INDEX BY PLS_INTEGER;
  TYPE tp_settings IS RECORD(
    page_width    NUMBER,
    page_height   NUMBER,
    margin_left   NUMBER,
    margin_right  NUMBER,
    margin_top    NUMBER,
    margin_bottom NUMBER);
  TYPE tp_settings_tab IS TABLE OF tp_settings INDEX BY PLS_INTEGER;

  TYPE tp_font IS RECORD(
    STANDARD BOOLEAN,
    family   VARCHAR2(100),
    style    VARCHAR2(2) -- N Normal
    -- I Italic
    -- B Bold
    -- BI Bold Italic
    ,
    SUBTYPE          VARCHAR2(15),
    NAME             VARCHAR2(100),
    fontname         VARCHAR2(100),
    char_width_tab   tp_pls_tab,
    encoding         VARCHAR2(100),
    charset          VARCHAR2(1000),
    compress_font    BOOLEAN := TRUE,
    fontsize         NUMBER,
    unit_norm        NUMBER,
    bb_xmin          PLS_INTEGER,
    bb_ymin          PLS_INTEGER,
    bb_xmax          PLS_INTEGER,
    bb_ymax          PLS_INTEGER,
    flags            PLS_INTEGER,
    first_char       PLS_INTEGER,
    last_char        PLS_INTEGER,
    italic_angle     NUMBER,
    ascent           PLS_INTEGER,
    descent          PLS_INTEGER,
    capheight        PLS_INTEGER,
    stemv            PLS_INTEGER,
    diff             VARCHAR2(32767),
    cid              BOOLEAN := FALSE,
    fontfile2        BLOB,
    ttf_offset       PLS_INTEGER,
    used_chars       tp_pls_tab,
    numGlyphs        PLS_INTEGER,
    indexToLocFormat PLS_INTEGER,
    loca             tp_pls_tab,
    code2glyph       tp_pls_tab,
    hmetrics         tp_pls_tab);
  TYPE tp_font_tab IS TABLE OF tp_font INDEX BY PLS_INTEGER;
  TYPE tp_img IS RECORD(
    adler32            VARCHAR2(8),
    width              PLS_INTEGER,
    height             PLS_INTEGER,
    color_res          PLS_INTEGER,
    color_tab          RAW(768),
    greyscale          BOOLEAN,
    pixels             BLOB,
    TYPE               VARCHAR2(5),
    nr_colors          PLS_INTEGER,
    transparancy_index PLS_INTEGER);
  TYPE tp_img_tab IS TABLE OF tp_img INDEX BY PLS_INTEGER;
  TYPE tp_info IS RECORD(
    title    VARCHAR2(1024),
    author   VARCHAR2(1024),
    subject  VARCHAR2(1024),
    keywords VARCHAR2(32767));
  TYPE tp_page_prcs IS TABLE OF CLOB INDEX BY PLS_INTEGER;
  --
  -- globals
  g_pdf_doc             BLOB; -- the PDF-document being constructed
  g_objects             tp_objects_tab;
  g_pages               tp_pages_tab;
  g_settings_per_page   tp_settings_tab;
  g_settings            tp_settings;
  g_fonts               tp_font_tab;
  g_used_fonts          tp_pls_tab;
  g_current_font        PLS_INTEGER;
  g_current_font_record tp_font;
  g_images              tp_img_tab;
  g_x                   NUMBER; -- current x-location of the "cursor"
  g_y                   NUMBER; -- current y-location of the "cursor"
  g_info                tp_info;
  g_page_nr             PLS_INTEGER;
  g_page_prcs           tp_page_prcs;
  --
  -- constants
  c_nl CONSTANT VARCHAR2(2) := chr(13) || chr(10);
  --
  FUNCTION num2raw(p_value NUMBER) RETURN RAW IS
  BEGIN
    RETURN hextoraw(to_char(p_value, 'FM0XXXXXXX'));
  END;
  --
  FUNCTION raw2num(p_value RAW) RETURN NUMBER IS
  BEGIN
    RETURN to_number(rawtohex(p_value), 'XXXXXXXX');
  END;
  --
  FUNCTION raw2num(p_value RAW,
                   p_pos   PLS_INTEGER,
                   p_len   PLS_INTEGER) RETURN PLS_INTEGER IS
  BEGIN
    RETURN to_number(rawtohex(utl_raw.substr(p_value, p_pos, p_len)), 'XXXXXXXX');
  END;
  --
  FUNCTION to_short(p_val    RAW,
                    p_factor NUMBER := 1) RETURN NUMBER IS
    t_rv NUMBER;
  BEGIN
    t_rv := to_number(rawtohex(p_val), 'XXXXXXXXXX');
    IF t_rv > 32767 THEN
      t_rv := t_rv - 65536;
    END IF;
    RETURN t_rv * p_factor;
  END;
  --
  FUNCTION blob2num(p_blob BLOB,
                    p_len  INTEGER,
                    p_pos  INTEGER) RETURN NUMBER IS
  BEGIN
    RETURN to_number(rawtohex(dbms_lob.substr(p_blob, p_len, p_pos)), 'xxxxxxxx');
  END;
  --
  FUNCTION file2blob(p_dir       VARCHAR2,
                     p_file_name VARCHAR2) RETURN BLOB IS
    t_raw  RAW(32767);
    t_blob BLOB;
    fh     utl_file.file_type;
  BEGIN
    fh := utl_file.fopen(p_dir, p_file_name, 'rb');
    dbms_lob.createtemporary(t_blob, TRUE);
    LOOP
      BEGIN
        utl_file.get_raw(fh, t_raw);
        dbms_lob.append(t_blob, t_raw);
      EXCEPTION
        WHEN no_data_found THEN
          EXIT;
      END;
    END LOOP;
    utl_file.fclose(fh);
    RETURN t_blob;
  EXCEPTION
    WHEN OTHERS THEN
      IF utl_file.is_open(fh) THEN
        utl_file.fclose(fh);
      END IF;
      RAISE;
  END;
  --
  PROCEDURE init_core_fonts IS
    FUNCTION uncompress_withs(p_compressed_tab VARCHAR2) RETURN tp_pls_tab IS
      t_rv  tp_pls_tab;
      t_tmp RAW(32767);
    BEGIN
      IF p_compressed_tab IS NOT NULL THEN
        t_tmp := utl_compress.lz_uncompress(utl_encode.base64_decode(utl_raw.cast_to_raw(p_compressed_tab)));
        FOR i IN 0 .. 255 LOOP
          t_rv(i) := to_number(utl_raw.substr(t_tmp, i * 4 + 1, 4), '0xxxxxxx');
        END LOOP;
      END IF;
      RETURN t_rv;
    END;
    --
    PROCEDURE init_core_font(p_ind            PLS_INTEGER,
                             p_family         VARCHAR2,
                             p_style          VARCHAR2,
                             p_name           VARCHAR2,
                             p_compressed_tab VARCHAR2) IS
    BEGIN
      g_fonts(p_ind).family := p_family;
      g_fonts(p_ind).style := p_style;
      g_fonts(p_ind).name := p_name;
      g_fonts(p_ind).fontname := p_name;
      g_fonts(p_ind).standard := TRUE;
      g_fonts(p_ind).encoding := 'WE8MSWIN1252';
      g_fonts(p_ind).charset := sys_context('userenv', 'LANGUAGE');
      g_fonts(p_ind).charset := substr(g_fonts(p_ind).charset, 1, instr(g_fonts(p_ind).charset, '.')) || g_fonts(p_ind).encoding;
      g_fonts(p_ind).char_width_tab := uncompress_withs(p_compressed_tab);
    END;
  BEGIN
    init_core_font(1, 'helvetica', 'N', 'Helvetica', 'H4sIAAAAAAAAC81Tuw3CMBC94FQMgMQOLAGVGzNCGtc0dAxAT+8lsgE7RKJFomOA' || 'SLT4frHjBEFJ8XSX87372C8A1Qr+Ax5gsWGYU7QBAK4x7gTnGLOS6xJPOd8w5NsM' || '2OvFvQidAP04j1nyN3F7iSNny3E6DylPeeqbNqvti31vMpfLZuzH86oPdwaeo6X+' ||
                    '5X6Oz5VHtTqJKfYRNVu6y0ZyG66rdcxzXJe+Q/KJ59kql+bTt5K6lKucXvxWeHKf' || '+p6Tfersfh7RHuXMZjHsdUkxBeWtM60gDjLTLoHeKsyDdu6m8VK3qhnUQAmca9BG' || 'Dq3nP+sV/4FcD6WOf9K/ne+hdav+DTuNLeYABAAA');
    --
    init_core_font(2, 'helvetica', 'I', 'Helvetica-Oblique', 'H4sIAAAAAAAAC81Tuw3CMBC94FQMgMQOLAGVGzNCGtc0dAxAT+8lsgE7RKJFomOA' || 'SLT4frHjBEFJ8XSX87372C8A1Qr+Ax5gsWGYU7QBAK4x7gTnGLOS6xJPOd8w5NsM' || '2OvFvQidAP04j1nyN3F7iSNny3E6DylPeeqbNqvti31vMpfLZuzH86oPdwaeo6X+' ||
                    '5X6Oz5VHtTqJKfYRNVu6y0ZyG66rdcxzXJe+Q/KJ59kql+bTt5K6lKucXvxWeHKf' || '+p6Tfersfh7RHuXMZjHsdUkxBeWtM60gDjLTLoHeKsyDdu6m8VK3qhnUQAmca9BG' || 'Dq3nP+sV/4FcD6WOf9K/ne+hdav+DTuNLeYABAAA');
    --
    init_core_font(3, 'helvetica', 'B', 'Helvetica-Bold', 'H4sIAAAAAAAAC8VSsRHCMAx0SJcBcgyRJaBKkxXSqKahYwB6+iyRTbhLSUdHRZUB' || 'sOWXLF8SKCn+ZL/0kizZuaJ2/0fn8XBu10SUF28n59wbvoCr51oTD61ofkHyhBwK' || '8rXusVaGAb4q3rXOBP4Qz+wfUpzo5FyO4MBr39IH+uLclFvmCTrz1mB5PpSD52N1' ||
                    'DfqS988xptibWfbw9Sa/jytf+dz4PqQz6wi63uxxBpCXY7uUj88jNDNy1mYGdl97' || '856nt2f4WsOFed4SpzumNCvlT+jpmKC7WgH3PJn9DaZfA42vlgh96d+wkHy0/V95' || 'xyv8oj59QbvBN2I/iAuqEAAEAAA=');
    --
    init_core_font(4, 'helvetica', 'BI', 'Helvetica-BoldOblique', 'H4sIAAAAAAAAC8VSsRHCMAx0SJcBcgyRJaBKkxXSqKahYwB6+iyRTbhLSUdHRZUB' || 'sOWXLF8SKCn+ZL/0kizZuaJ2/0fn8XBu10SUF28n59wbvoCr51oTD61ofkHyhBwK' || '8rXusVaGAb4q3rXOBP4Qz+wfUpzo5FyO4MBr39IH+uLclFvmCTrz1mB5PpSD52N1' ||
                    'DfqS988xptibWfbw9Sa/jytf+dz4PqQz6wi63uxxBpCXY7uUj88jNDNy1mYGdl97' || '856nt2f4WsOFed4SpzumNCvlT+jpmKC7WgH3PJn9DaZfA42vlgh96d+wkHy0/V95' || 'xyv8oj59QbvBN2I/iAuqEAAEAAA=');
    --
    init_core_font(5, 'times', 'N', 'Times-Roman', 'H4sIAAAAAAAAC8WSKxLCQAyG+3Bopo4bVHbwHGCvUNNT9AB4JEwvgUBimUF3wCNR' || 'qAoGRZL9twlQikR8kzTvZBtF0SP6O7Ej1kTnSRfEhHw7+Jy3J4XGi8w05yeZh2sE' || '4j312ZDeEg1gvSJy6C36L9WX1urr4xrolfrSrYmrUCeDPGMu5+cQ3Ur3OXvQ+TYf' ||
                    '+2FGexOZvTM1L3S3o5fJjGQJX2n68U2ur3X5m3cTvfbxsk9pcsMee60rdTjnhNkc' || 'Zip9HOv9+7/tI3Oif3InOdV/oLdx3gq2HIRaB1Ob7XPk35QwwxDyxg3e09Dv6nSf' || 'rxQjvty8ywDce9CXvdF9R+4y4o+7J1P/I9sABAAA');
    --
    init_core_font(6, 'times', 'I', 'Times-Italic', 'H4sIAAAAAAAAC8WSPQ6CQBCFF+i01NB5g63tPcBegYZTeAB6SxNLjLUH4BTEeAYr' || 'Kwpj5ezsW2YgoKXFl2Hnb9+wY4x5m7+TOOJMdIFsRywodkfMBX9aSz7bXGp+gj6+' || 'R4TvOtJ3CU5Eq85tgGsbxG3QN8iFZY1WzpxXwkckFTR7e1G6osZGWT1bDuBnTeP5' ||
                    'KtW/E71c0yB2IFbBphuyBXIL9Y/9fPvhf8se6vsa8nmeQtU6NSf6ch9fc8P9DpqK' || 'cPa5/I7VxDwruTN9kV3LDvQ+h1m8z4I4x9LIbnn/Fv6nwOdyGq+d33jk7/cxztyq' || 'XRhTz/it7Mscg7fT5CO+9ahnYk20Hww5IrwABAAA');
    --
    init_core_font(7, 'times', 'B', 'Times-Bold', 'H4sIAAAAAAAAC8VSuw3CQAy9XBqUAVKxAZkgHQUNEiukySxpqOjTMQEDZIrUDICE' || 'RHUVVfy9c0IQJcWTfbafv+ece7u/Izs553cgAyN/APagl+wjgN3XKZ5kmTg/IXkw' || 'h4JqXUEfAb1I1VvwFYysk9iCffmN4+gtccSr5nlwDpuTepCZ/MH0FZibDUnO7MoR' ||
                    'HXdDuvgjpzNxgevG+dF/hr3dWfoNyEZ8Taqn+7d7ozmqpGM8zdMYruFrXopVjvY2' || 'in9gXe+5vBf1KfX9E6TOVBsb8i5iqwQyv9+a3Gg/Cv+VoDtaQ7xdPwfNYRDji09g' || 'X/FvLNGmO62B9jSsoFwgfM+jf1z/SPwrkTMBOkCTBQAEAAA=');
    --
    init_core_font(8, 'times', 'BI', 'Times-BoldItalic', 'H4sIAAAAAAAAC8WSuw2DMBCGHegYwEuECajIAGwQ0TBFBnCfPktkAKagzgCRIqWi' || 'oso9fr+Qo5RB+nT2ve+wMWYzf+fgjKmOJFelPhENnS0xANJXHfwHSBtjfoI8nMMj' || 'tXo63xKW/Cx9ONRn3US6C/wWvYeYNr+LH2IY6cHGPkJfvsc5kX7mFjF+Vqs9iT6d' ||
                    'zwEL26y1Qz62nWlvD5VSf4R9zPuon/ne+C45+XxXf5lnTGLTOZCXPx8v9Qfdjdid' || '5vD/f/+/pE/Ur14kG+xjTHRc84pZWsC2Hjk2+Hgbx78j4Z8W4DlL+rBnEN5Bie6L' || 'fsL+1u/InuYCdsdaeAs+RxftKfGdfQDlDF/kAAQAAA==');
    --
    init_core_font(9, 'courier', 'N', 'Courier', NULL);
    FOR i IN 0 .. 255 LOOP
      g_fonts(9).char_width_tab(i) := 600;
    END LOOP;
    --
    init_core_font(10, 'courier', 'I', 'Courier-Oblique', NULL);
    g_fonts(10).char_width_tab := g_fonts(9).char_width_tab;
    --
    init_core_font(11, 'courier', 'B', 'Courier-Bold', NULL);
    g_fonts(11).char_width_tab := g_fonts(9).char_width_tab;
    --
    init_core_font(12, 'courier', 'BI', 'Courier-BoldOblique', NULL);
    g_fonts(12).char_width_tab := g_fonts(9).char_width_tab;
    --
    init_core_font(13, 'symbol', 'N', 'Symbol', 'H4sIAAAAAAAAC82SIU8DQRCFZ28xIE+cqcbha4tENKk/gQCJJ6AweIK9H1CHqKnp' || 'D2gTFBaDIcFwCQkJSTG83fem7SU0qYNLvry5nZ25t7NnZkv7c8LQrFhAP6GHZvEY' || 'HOB9ylxGubTfNVRc34mKpFonzBQ/gUZ6Ds7AN6i5lv1dKv8Ab1eKQYSV4hUcgZFq' ||
                    'J/Sec7fQHtdTn3iqfvdrb7m3e2pZW+xDG3oIJ/Li3gfMr949rlU74DyT1/AuTX1f' || 'YGhOzTP8B0/RggsEX/I03vgXPrrslZjfM8/pGu40t2ZjHgud97F7337mXP/GO4h9' || '3WmPPaOJ/jrOs9yC52MlrtUzfWupfTX51X/L+13Vl/J/s4W2S3pSfSh5DmeXerMf' || '+LXhWQAEAAA=');
    --
    init_core_font(14, 'zapfdingbats', 'N', 'ZapfDingbats', 'H4sIAAAAAAAAC83ROy9EQRjG8TkzjdJl163SSHR0EpdsVkSi2UahFhUljUKUIgoq' || 'CrvJCtFQyG6EbSSERGxhC0ofQAQFxbIi8T/7PoUPIOEkvzxzzsycdy7O/fUTtToX' || 'bnCuvHPOV8gk4r423ovkGQ5od5OTWMeesmBz/RuZIWv4wCAY4z/xjipeqflC9qAD' ||
                    'aRwxrxkJievSFzrRh36tZ1zttL6nkGX+A27xrLnttE/IBji9x7UvcIl9nPJ9AL36' || 'd1L9hyihoDW10L62cwhNyhntryZVExYl3kMj+zym+CrJv6M8VozPmfr5L8uwJORL' || 'tox7NFHG/Obj79FlwhqZ1X292xn6CbAXP/fjjv6rJYyBtUdl1vxEO6fcRB7bMmJ3' ||
                    'GYZsTN0GdrDL/Ao5j1GZNr5kwqydX5z1syoiYEq5gCtlSrXi+mVbi3PfVAuhoQAE' || 'AAA=');
    --
  END;
  --
  FUNCTION to_char_round(p_value     NUMBER,
                         p_precision PLS_INTEGER := 2) RETURN VARCHAR2 IS
  BEGIN
    RETURN to_char(round(p_value, p_precision), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,');
  END;
  --
  PROCEDURE raw2pdfdoc(p_raw BLOB) IS
  BEGIN
    dbms_lob.append(g_pdf_doc, p_raw);
  END;
  --
  PROCEDURE txt2pdfdoc(p_txt VARCHAR2) IS
  BEGIN
    raw2pdfdoc(utl_raw.cast_to_raw(p_txt || c_nl));
  END;
  --
  FUNCTION add_object(p_txt VARCHAR2 := NULL) RETURN NUMBER IS
    t_self NUMBER(10);
  BEGIN
    t_self := g_objects.count();
    g_objects(t_self) := dbms_lob.getlength(g_pdf_doc);
    --
    IF p_txt IS NULL THEN
      txt2pdfdoc(t_self || ' 0 obj');
    ELSE
      txt2pdfdoc(t_self || ' 0 obj' || c_nl || '<<' || p_txt || '>>' || c_nl || 'endobj');
    END IF;
    --
    RETURN t_self;
  END;
  --
  PROCEDURE add_object(p_txt VARCHAR2 := NULL) IS
    t_dummy NUMBER(10) := add_object(p_txt);
  BEGIN
    NULL;
  END;
  --
  FUNCTION adler32(p_src IN BLOB) RETURN VARCHAR2 IS
    s1        PLS_INTEGER := 1;
    s2        PLS_INTEGER := 0;
    n         PLS_INTEGER;
    step_size NUMBER;
    tmp       VARCHAR2(32766);
    c65521 CONSTANT PLS_INTEGER := 65521;
  BEGIN
    step_size := trunc(16383 / dbms_lob.getchunksize(p_src)) * dbms_lob.getchunksize(p_src);
    FOR j IN 0 .. trunc((dbms_lob.getlength(p_src) - 1) / step_size) LOOP
      tmp := rawtohex(dbms_lob.substr(p_src, step_size, j * step_size + 1));
      FOR i IN 1 .. length(tmp) / 2 LOOP
        n  := lHex(substr(tmp, i * 2 - 1, 2)); --n := to_number( substr( tmp, i * 2 - 1, 2 ), 'xx' );
        s1 := s1 + n;
        IF s1 >= c65521 THEN
          s1 := s1 - c65521;
        END IF;
        s2 := s2 + s1;
        IF s2 >= c65521 THEN
          s2 := s2 - c65521;
        END IF;
      END LOOP;
    END LOOP;
    RETURN to_char(s2, 'fm0XXX') || to_char(s1, 'fm0XXX');
  END;
  --
  FUNCTION flate_encode(p_val BLOB) RETURN BLOB IS
    t_blob BLOB;
  BEGIN
    t_blob := hextoraw('789C');
    dbms_lob.copy(t_blob, utl_compress.lz_compress(p_val), dbms_lob.lobmaxsize, 3, 11);
    dbms_lob.trim(t_blob, dbms_lob.getlength(t_blob) - 8);
    dbms_lob.append(t_blob, hextoraw(adler32(p_val)));
    RETURN t_blob;
  END;
  --
  PROCEDURE put_stream(p_stream   BLOB,
                       p_compress BOOLEAN := TRUE,
                       p_extra    VARCHAR2 := '',
                       p_tag      BOOLEAN := TRUE) IS
    t_blob     BLOB;
    t_compress BOOLEAN := FALSE;
  BEGIN
    IF p_compress
       AND nvl(dbms_lob.getlength(p_stream), 0) > 0 THEN
      t_compress := TRUE;
      t_blob     := flate_encode(p_stream);
    ELSE
      t_blob := p_stream;
    END IF;
    txt2pdfdoc(CASE WHEN p_tag THEN '<<' END || CASE WHEN t_compress THEN '/Filter /FlateDecode ' END || '/Length ' || nvl(length(t_blob), 0) || p_extra || '>>');
    txt2pdfdoc('stream');
    raw2pdfdoc(t_blob);
    txt2pdfdoc('endstream');
    IF dbms_lob.istemporary(t_blob) = 1 THEN
      dbms_lob.freetemporary(t_blob);
    END IF;
  END;
  --
  FUNCTION add_stream(p_stream   BLOB,
                      p_extra    VARCHAR2 := '',
                      p_compress BOOLEAN := TRUE) RETURN NUMBER IS
    t_self NUMBER(10);
  BEGIN
    t_self := add_object;
    put_stream(p_stream, p_compress, p_extra);
    txt2pdfdoc('endobj');
    RETURN t_self;
  END;
  --
  FUNCTION subset_font(p_index PLS_INTEGER) RETURN BLOB IS
    t_tmp           BLOB;
    t_header        BLOB;
    t_tables        BLOB;
    t_len           PLS_INTEGER;
    t_code          PLS_INTEGER;
    t_glyph         PLS_INTEGER;
    t_offset        PLS_INTEGER;
    t_factor        PLS_INTEGER;
    t_unicode       PLS_INTEGER;
    t_used_glyphs   tp_pls_tab;
    t_fmt           VARCHAR2(10);
    t_utf16_charset VARCHAR2(1000);
    t_raw           RAW(32767);
    t_v             VARCHAR2(32767);
    t_table_records RAW(32767);
  BEGIN
    IF g_fonts(p_index).cid THEN
      t_used_glyphs := g_fonts(p_index).used_chars;
      t_used_glyphs(0) := 0;
    ELSE
      t_utf16_charset := substr(g_fonts(p_index).charset, 1, instr(g_fonts(p_index).charset, '.')) || 'AL16UTF16';
      t_used_glyphs(0) := 0;
      t_code := g_fonts(p_index).used_chars.first;
      WHILE t_code IS NOT NULL LOOP
        t_unicode := to_number(rawtohex(utl_raw.convert(hextoraw(to_char(t_code, 'fm0x')), t_utf16_charset, g_fonts(p_index).charset -- ???? database characterset ?????
                                                        )), 'XXXXXXXX');
        IF g_fonts(p_index).flags = 4 -- a symbolic font
         THEN
          -- assume code 32, space maps to the first code from the font
          t_used_glyphs(g_fonts(p_index).code2glyph(g_fonts(p_index).code2glyph.first + t_unicode - 32)) := 0;
        ELSE
          t_used_glyphs(g_fonts(p_index).code2glyph(t_unicode)) := 0;
        END IF;
        t_code := g_fonts(p_index).used_chars.next(t_code);
      END LOOP;
    END IF;
    --
    dbms_lob.createtemporary(t_tables, TRUE);
    t_header        := utl_raw.concat(hextoraw('00010000'), dbms_lob.substr(g_fonts(p_index).fontfile2, 8, g_fonts(p_index).ttf_offset + 4));
    t_offset        := 12 + blob2num(g_fonts(p_index).fontfile2, 2, g_fonts(p_index).ttf_offset + 4) * 16;
    t_table_records := dbms_lob.substr(g_fonts(p_index).fontfile2, blob2num(g_fonts(p_index).fontfile2, 2, g_fonts(p_index).ttf_offset + 4) * 16, g_fonts(p_index).ttf_offset + 12);
    FOR i IN 1 .. blob2num(g_fonts(p_index).fontfile2, 2, g_fonts(p_index).ttf_offset + 4) LOOP
      CASE utl_raw.cast_to_varchar2(utl_raw.substr(t_table_records, i * 16 - 15, 4))
        WHEN 'post' THEN
          dbms_lob.append(t_header, utl_raw.concat(utl_raw.substr(t_table_records, i * 16 - 15, 4) -- tag
                                         , hextoraw('00000000') -- checksum
                                         , num2raw(t_offset + dbms_lob.getlength(t_tables)) -- offset
                                         , num2raw(32) -- length
                                          ));
          dbms_lob.append(t_tables, utl_raw.concat(hextoraw('00030000'), dbms_lob.substr(g_fonts(p_index).fontfile2, 28, raw2num(t_table_records, i * 16 - 7, 4) + 5)));
        WHEN 'loca' THEN
          IF g_fonts(p_index).indexToLocFormat = 0 THEN
            t_fmt := 'fm0XXX';
          ELSE
            t_fmt := 'fm0XXXXXXX';
          END IF;
          t_raw := NULL;
          dbms_lob.createtemporary(t_tmp, TRUE);
          t_len := 0;
          FOR g IN 0 .. g_fonts(p_index).numGlyphs - 1 LOOP
            t_raw := utl_raw.concat(t_raw, hextoraw(to_char(t_len, t_fmt)));
            IF utl_raw.length(t_raw) > 32770 THEN
              dbms_lob.append(t_tmp, t_raw);
              t_raw := NULL;
            END IF;
            IF t_used_glyphs.exists(g) THEN
              t_len := t_len + g_fonts(p_index).loca(g + 1) - g_fonts(p_index).loca(g);
            END IF;
          END LOOP;
          t_raw := utl_raw.concat(t_raw, hextoraw(to_char(t_len, t_fmt)));
          dbms_lob.append(t_tmp, t_raw);
          dbms_lob.append(t_header, utl_raw.concat(utl_raw.substr(t_table_records, i * 16 - 15, 4) -- tag
                                         , hextoraw('00000000') -- checksum
                                         , num2raw(t_offset + dbms_lob.getlength(t_tables)) -- offset
                                         , num2raw(dbms_lob.getlength(t_tmp)) -- length
                                          ));
          dbms_lob.append(t_tables, t_tmp);
          dbms_lob.freetemporary(t_tmp);
        WHEN 'glyf' THEN
          IF g_fonts(p_index).indexToLocFormat = 0 THEN
            t_factor := 2;
          ELSE
            t_factor := 1;
          END IF;
          t_raw := NULL;
          dbms_lob.createtemporary(t_tmp, TRUE);
          FOR g IN 0 .. g_fonts(p_index).numGlyphs - 1 LOOP
            IF (t_used_glyphs.exists(g) AND g_fonts(p_index).loca(g + 1) > g_fonts(p_index).loca(g)) THEN
              t_raw := utl_raw.concat(t_raw, dbms_lob.substr(g_fonts(p_index).fontfile2, (g_fonts(p_index).loca(g + 1) - g_fonts(p_index).loca(g)) * t_factor, g_fonts(p_index).loca(g) * t_factor + raw2num(t_table_records, i * 16 - 7, 4) + 1));
              IF utl_raw.length(t_raw) > 32000 THEN
                dbms_lob.append(t_tmp, t_raw);
                t_raw := NULL;
              END IF;
            END IF;
          END LOOP;
          IF utl_raw.length(t_raw) > 0 THEN
            dbms_lob.append(t_tmp, t_raw);
          END IF;
          dbms_lob.append(t_header, utl_raw.concat(utl_raw.substr(t_table_records, i * 16 - 15, 4) -- tag
                                         , hextoraw('00000000') -- checksum
                                         , num2raw(t_offset + dbms_lob.getlength(t_tables)) -- offset
                                         , num2raw(dbms_lob.getlength(t_tmp)) -- length
                                          ));
          dbms_lob.append(t_tables, t_tmp);
          dbms_lob.freetemporary(t_tmp);
        ELSE
          dbms_lob.append(t_header, utl_raw.concat(utl_raw.substr(t_table_records, i * 16 - 15, 4) -- tag
                                         , utl_raw.substr(t_table_records, i * 16 - 11, 4) -- checksum
                                         , num2raw(t_offset + dbms_lob.getlength(t_tables)) -- offset
                                         , utl_raw.substr(t_table_records, i * 16 - 3, 4) -- length
                                          ));
          dbms_lob.copy(t_tables, g_fonts(p_index).fontfile2, raw2num(t_table_records, i * 16 - 3, 4), dbms_lob.getlength(t_tables) + 1, raw2num(t_table_records, i * 16 - 7, 4) + 1);
      END CASE;
    END LOOP;
    dbms_lob.append(t_header, t_tables);
    dbms_lob.freetemporary(t_tables);
    RETURN t_header;
  END;
  --
  FUNCTION add_font(p_index PLS_INTEGER) RETURN NUMBER IS
    t_self          NUMBER(10);
    t_fontfile      NUMBER(10);
    t_font_subset   BLOB;
    t_used          PLS_INTEGER;
    t_used_glyphs   tp_pls_tab;
    t_w             VARCHAR2(32767);
    t_unicode       PLS_INTEGER;
    t_utf16_charset VARCHAR2(1000);
    t_width         NUMBER;
  BEGIN
    IF g_fonts(p_index).standard THEN
      RETURN add_object('/Type/Font' || '/Subtype/Type1' || '/BaseFont/' || g_fonts(p_index).name || '/Encoding/WinAnsiEncoding' -- code page 1252
                        );
    END IF;
    --
    IF g_fonts(p_index).cid THEN
      t_self := add_object;
      txt2pdfdoc('<</Type/Font/Subtype/Type0/Encoding/Identity-H' || '/BaseFont/' || g_fonts(p_index).name || '/DescendantFonts ' || to_char(t_self + 1) || ' 0 R' || '/ToUnicode ' || to_char(t_self + 8) || ' 0 R' || '>>');
      txt2pdfdoc('endobj');
      add_object;
      txt2pdfdoc('[' || to_char(t_self + 2) || ' 0 R]');
      txt2pdfdoc('endobj');
      add_object('/Type/Font/Subtype/CIDFontType2/CIDToGIDMap/Identity/DW 1000' || '/BaseFont/' || g_fonts(p_index).name || '/CIDSystemInfo ' || to_char(t_self + 3) || ' 0 R' || '/W ' || to_char(t_self + 4) || ' 0 R' || '/FontDescriptor ' || to_char(t_self + 5) || ' 0 R');
      add_object('/Ordering(Identity) /Registry(Adobe) /Supplement 0');
      --
      t_utf16_charset := substr(g_fonts(p_index).charset, 1, instr(g_fonts(p_index).charset, '.')) || 'AL16UTF16';
      t_used_glyphs := g_fonts(p_index).used_chars;
      t_used_glyphs(0) := 0;
      t_used := t_used_glyphs.first();
      WHILE t_used IS NOT NULL LOOP
        IF g_fonts(p_index).hmetrics.exists(t_used) THEN
          t_width := g_fonts(p_index).hmetrics(t_used);
        ELSE
          t_width := g_fonts(p_index).hmetrics(g_fonts(p_index).hmetrics.last());
        END IF;
        t_width := trunc(t_width * g_fonts(p_index).unit_norm);
        IF t_used_glyphs.prior(t_used) = t_used - 1 THEN
          t_w := t_w || ' ' || t_width;
        ELSE
          t_w := t_w || '] ' || t_used || ' [' || t_width;
        END IF;
        t_used := t_used_glyphs.next(t_used);
      END LOOP;
      t_w := '[' || ltrim(t_w, '] ') || ']]';
      add_object;
      txt2pdfdoc(t_w);
      txt2pdfdoc('endobj');
      add_object('/Type/FontDescriptor' || '/FontName/' || g_fonts(p_index).name || '/Flags ' || g_fonts(p_index).flags || '/FontBBox [' || g_fonts(p_index).bb_xmin || ' ' || g_fonts(p_index).bb_ymin || ' ' || g_fonts(p_index).bb_xmax || ' ' || g_fonts(p_index).bb_ymax || ']' || '/ItalicAngle ' ||
                 to_char_round(g_fonts(p_index).italic_angle) || '/Ascent ' || g_fonts(p_index).ascent || '/Descent ' || g_fonts(p_index).descent || '/CapHeight ' || g_fonts(p_index).capheight || '/StemV ' || g_fonts(p_index).stemv || '/FontFile2 ' || to_char(t_self + 6) || ' 0 R');
      t_fontfile    := add_stream(g_fonts(p_index).fontfile2, '/Length1 ' || dbms_lob.getlength(g_fonts(p_index).fontfile2), g_fonts(p_index).compress_font);
      t_font_subset := subset_font(p_index);
      t_fontfile    := add_stream(t_font_subset, '/Length1 ' || dbms_lob.getlength(t_font_subset), g_fonts(p_index).compress_font);
      DECLARE
        t_g2c     tp_pls_tab;
        t_code    PLS_INTEGER;
        t_c_start PLS_INTEGER;
        t_map     VARCHAR2(32767);
        t_cmap    VARCHAR2(32767);
        t_cor     PLS_INTEGER;
        t_cnt     PLS_INTEGER;
      BEGIN
        t_code := g_fonts(p_index).code2glyph.first;
        IF g_fonts(p_index).flags = 4 -- a symbolic font
         THEN
          -- assume code 32, space maps to the first code from the font
          t_cor := t_code - 32;
        ELSE
          t_cor := 0;
        END IF;
        WHILE t_code IS NOT NULL LOOP
          t_g2c(g_fonts(p_index).code2glyph(t_code)) := t_code - t_cor;
          t_code := g_fonts(p_index).code2glyph.next(t_code);
        END LOOP;
        t_cnt         := 0;
        t_used_glyphs := g_fonts(p_index).used_chars;
        t_used        := t_used_glyphs.first();
        WHILE t_used IS NOT NULL LOOP
          t_map := t_map || '<' || to_char(t_used, 'FM0XXX') || '> <' || to_char(t_g2c(t_used), 'FM0XXX') || '>' || chr(10);
          IF t_cnt = 99 THEN
            t_cnt  := 0;
            t_cmap := t_cmap || chr(10) || '100 beginbfchar' || chr(10) || t_map || 'endbfchar';
            t_map  := '';
          ELSE
            t_cnt := t_cnt + 1;
          END IF;
          t_used := t_used_glyphs.next(t_used);
        END LOOP;
        IF t_cnt > 0 THEN
          t_cmap := t_cnt || ' beginbfchar' || chr(10) || t_map || 'endbfchar';
        END IF;
        t_fontfile := add_stream(utl_raw.cast_to_raw('/CIDInit /ProcSet findresource begin 12 dict begin
begincmap
/CIDSystemInfo
<< /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /Adobe-Identity-UCS def /CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
' || t_cmap || '
endcmap
CMapName currentdict /CMap defineresource pop
end
end'));
      END;
      RETURN t_self;
    END IF;
    --
    g_fonts(p_index).first_char := g_fonts(p_index).used_chars.first();
    g_fonts(p_index).last_char := g_fonts(p_index).used_chars.last();
    t_self := add_object;
    txt2pdfdoc('<</Type /Font ' || '/Subtype /' || g_fonts(p_index).subtype || ' /BaseFont /' || g_fonts(p_index).name || ' /FirstChar ' || g_fonts(p_index).first_char || ' /LastChar ' || g_fonts(p_index).last_char || ' /Widths ' || to_char(t_self + 1) || ' 0 R' || ' /FontDescriptor ' ||
               to_char(t_self + 2) || ' 0 R' || ' /Encoding ' || to_char(t_self + 3) || ' 0 R' || ' >>');
    txt2pdfdoc('endobj');
    add_object;
    txt2pdfdoc('[');
    BEGIN
      FOR i IN g_fonts(p_index).first_char .. g_fonts(p_index).last_char LOOP
        txt2pdfdoc(g_fonts(p_index).char_width_tab(i));
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('**** ' || g_fonts(p_index).name);
    END;
    txt2pdfdoc(']');
    txt2pdfdoc('endobj');
    add_object('/Type /FontDescriptor' || ' /FontName /' || g_fonts(p_index).name || ' /Flags ' || g_fonts(p_index).flags || ' /FontBBox [' || g_fonts(p_index).bb_xmin || ' ' || g_fonts(p_index).bb_ymin || ' ' || g_fonts(p_index).bb_xmax || ' ' || g_fonts(p_index).bb_ymax || ']' ||
               ' /ItalicAngle ' || to_char_round(g_fonts(p_index).italic_angle) || ' /Ascent ' || g_fonts(p_index).ascent || ' /Descent ' || g_fonts(p_index).descent || ' /CapHeight ' || g_fonts(p_index).capheight || ' /StemV ' || g_fonts(p_index).stemv || CASE WHEN g_fonts(p_index)
               .fontfile2 IS NOT NULL THEN ' /FontFile2 ' || to_char(t_self + 4) || ' 0 R' END);
    add_object('/Type /Encoding /BaseEncoding /WinAnsiEncoding ' || g_fonts(p_index).diff || ' ');
    IF g_fonts(p_index).fontfile2 IS NOT NULL THEN
      t_font_subset := subset_font(p_index);
      t_fontfile    := add_stream(t_font_subset, '/Length1 ' || dbms_lob.getlength(t_font_subset), g_fonts(p_index).compress_font);
    END IF;
    RETURN t_self;
  END;
  --
  PROCEDURE add_image(p_img tp_img) IS
    t_pallet NUMBER(10);
  BEGIN
    IF p_img.color_tab IS NOT NULL THEN
      t_pallet := add_stream(p_img.color_tab);
    ELSE
      t_pallet := add_object; -- add an empty object
      txt2pdfdoc('endobj');
    END IF;
    add_object;
    txt2pdfdoc('<</Type /XObject /Subtype /Image' || ' /Width ' || to_char(p_img.width) || ' /Height ' || to_char(p_img.height) || ' /BitsPerComponent ' || to_char(p_img.color_res));
    --
    IF p_img.transparancy_index IS NOT NULL THEN
      txt2pdfdoc('/Mask [' || p_img.transparancy_index || ' ' || p_img.transparancy_index || ']');
    END IF;
    IF p_img.color_tab IS NULL THEN
      IF p_img.greyscale THEN
        txt2pdfdoc('/ColorSpace /DeviceGray');
      ELSE
        txt2pdfdoc('/ColorSpace /DeviceRGB');
      END IF;
    ELSE
      txt2pdfdoc('/ColorSpace [/Indexed /DeviceRGB ' || to_char(utl_raw.length(p_img.color_tab) / 3 - 1) || ' ' || to_char(t_pallet) || ' 0 R]');
    END IF;
    --
    IF p_img.type = 'jpg' THEN
      put_stream(p_img.pixels, FALSE, '/Filter /DCTDecode', FALSE);
    ELSIF p_img.type = 'png' THEN
      put_stream(p_img.pixels, FALSE, ' /Filter /FlateDecode /DecodeParms <</Predictor 15 ' || '/Colors ' || p_img.nr_colors || '/BitsPerComponent ' || p_img.color_res || ' /Columns ' || p_img.width || ' >> ', FALSE);
    ELSE
      put_stream(p_img.pixels, p_tag => FALSE);
    END IF;
    txt2pdfdoc('endobj');
  END;
  --
  FUNCTION add_resources RETURN NUMBER IS
    t_ind   PLS_INTEGER;
    t_self  NUMBER(10);
    t_fonts tp_objects_tab;
  BEGIN
    --
    t_ind := g_used_fonts.first;
    WHILE t_ind IS NOT NULL LOOP
      t_fonts(t_ind) := add_font(t_ind);
      t_ind := g_used_fonts.next(t_ind);
    END LOOP;
    --
    t_self := add_object;
    txt2pdfdoc('<</ProcSet [/PDF /Text]');
    --
    IF g_used_fonts.count() > 0 THEN
      txt2pdfdoc('/Font <<');
      t_ind := g_used_fonts.first;
      WHILE t_ind IS NOT NULL LOOP
        txt2pdfdoc('/F' || to_char(t_ind) || ' ' || to_char(t_fonts(t_ind)) || ' 0 R');
        t_ind := g_used_fonts.next(t_ind);
      END LOOP;
      txt2pdfdoc('>>');
    END IF;
    --
    IF g_images.count() > 0 THEN
      txt2pdfdoc('/XObject <<');
      FOR i IN g_images.first .. g_images.last LOOP
        txt2pdfdoc('/I' || to_char(i) || ' ' || to_char(t_self + 2 * i) || ' 0 R');
      END LOOP;
      txt2pdfdoc('>>');
    END IF;
    --
    txt2pdfdoc('>>');
    txt2pdfdoc('endobj');
    --
    IF g_images.count() > 0 THEN
      FOR i IN g_images.first .. g_images.last LOOP
        add_image(g_images(i));
      END LOOP;
    END IF;
    RETURN t_self;
  END;
  --
  PROCEDURE add_page(p_page_ind  PLS_INTEGER,
                     p_parent    NUMBER,
                     p_resources NUMBER) IS
    t_content NUMBER(10);
  BEGIN
    t_content := add_stream(g_pages(p_page_ind));
    add_object;
    txt2pdfdoc('<< /Type /Page');
    txt2pdfdoc('/Parent ' || to_char(p_parent) || ' 0 R');
    -- AW: Add a mediabox to each page
    txt2pdfdoc('/MediaBox [0 0 ' || to_char_round(g_settings_per_page(p_page_ind).page_width, 0) || ' ' || to_char_round(g_settings_per_page(p_page_ind).page_height, 0) || ']');
  
    txt2pdfdoc('/Contents ' || to_char(t_content) || ' 0 R');
    txt2pdfdoc('/Resources ' || to_char(p_resources) || ' 0 R');
    txt2pdfdoc('>>');
    txt2pdfdoc('endobj');
  END;
  --
  FUNCTION add_pages RETURN NUMBER IS
    t_self      NUMBER(10);
    t_resources NUMBER(10);
  BEGIN
    t_resources := add_resources;
    t_self      := add_object;
    txt2pdfdoc('<</Type/Pages/Kids [');
    --
    FOR i IN g_pages.first .. g_pages.last LOOP
      txt2pdfdoc(to_char(t_self + i * 2 + 2) || ' 0 R');
    END LOOP;
    --
    -- AW: take the settings from page 1 as global settings
    IF g_settings_per_page.EXISTS(0) THEN
      g_settings := g_settings_per_page(0);
    END IF;
    txt2pdfdoc(']');
    txt2pdfdoc('/Count ' || g_pages.count());
    txt2pdfdoc('/MediaBox [0 0 ' || to_char_round(g_settings.page_width, 0) || ' ' || to_char_round(g_settings.page_height, 0) || ']');
    txt2pdfdoc('>>');
    txt2pdfdoc('endobj');
    --
    IF g_pages.count() > 0 THEN
      FOR i IN g_pages.first .. g_pages.last LOOP
        add_page(i, t_self, t_resources);
      END LOOP;
    END IF;
    --
    RETURN t_self;
  END;
  --
  FUNCTION add_catalogue RETURN NUMBER IS
  BEGIN
    RETURN add_object('/Type/Catalog' || '/Pages ' || to_char(add_pages) || ' 0 R' || '/OpenAction [0 /XYZ null null 0.77]');
  END;
  --
  FUNCTION add_info RETURN NUMBER IS
    t_banner VARCHAR2(1000);
  BEGIN
    BEGIN
      SELECT 'running on ' || REPLACE(REPLACE(REPLACE(substr(banner, 1, 950), '\', '\\'), '(', '\('), ')', '\)') INTO t_banner FROM v$version WHERE instr(upper(banner), 'DATABASE') > 0;
      t_banner := '/Producer (' || t_banner || ')';
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    --
    RETURN add_object(to_char(SYSDATE, '"/CreationDate (D:"YYYYMMDDhh24miss")"') || '/Creator (AS-PDF 0.3.0 by Anton Scheffer)' || t_banner || '/Title <FEFF' || utl_i18n.string_to_raw(g_info.title, 'AL16UTF16') || '>' || '/Author <FEFF' || utl_i18n.string_to_raw(g_info.author, 'AL16UTF16') || '>' ||
                      '/Subject <FEFF' || utl_i18n.string_to_raw(g_info.subject, 'AL16UTF16') || '>' || '/Keywords <FEFF' || utl_i18n.string_to_raw(g_info.keywords, 'AL16UTF16') || '>');
  END;
  --
  PROCEDURE finish_pdf IS
    t_xref      NUMBER;
    t_info      NUMBER(10);
    t_catalogue NUMBER(10);
  BEGIN
    IF g_pages.count = 0 THEN
      new_page;
    END IF;
    IF g_page_prcs.count > 0 THEN
      FOR i IN g_pages.first .. g_pages.last LOOP
        g_page_nr := i;
        FOR p IN g_page_prcs.first .. g_page_prcs.last LOOP
          BEGIN
            EXECUTE IMMEDIATE REPLACE(REPLACE(g_page_prcs(p), '#PAGE_NR#', i + 1), '"PAGE_COUNT#', g_pages.count);
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;
      END LOOP;
    END IF;
    dbms_lob.createtemporary(g_pdf_doc, TRUE);
    txt2pdfdoc('%PDF-1.3');
    raw2pdfdoc(hextoraw('25E2E3CFD30D0A')); -- add a hex comment
    t_info      := add_info;
    t_catalogue := add_catalogue;
    t_xref      := dbms_lob.getlength(g_pdf_doc);
    txt2pdfdoc('xref');
    txt2pdfdoc('0 ' || to_char(g_objects.count()));
    txt2pdfdoc('0000000000 65535 f ');
    FOR i IN 1 .. g_objects.count() - 1 LOOP
      txt2pdfdoc(to_char(g_objects(i), 'fm0000000000') || ' 00000 n');
      -- this line should be exactly 20 bytes, including EOL
    END LOOP;
    txt2pdfdoc('trailer');
    txt2pdfdoc('<< /Root ' || to_char(t_catalogue) || ' 0 R');
    txt2pdfdoc('/Info ' || to_char(t_info) || ' 0 R');
    txt2pdfdoc('/Size ' || to_char(g_objects.count()));
    txt2pdfdoc('>>');
    txt2pdfdoc('startxref');
    txt2pdfdoc(to_char(t_xref));
    txt2pdfdoc('%%EOF');
    --
    g_objects.delete;
    FOR i IN g_pages.first .. g_pages.last LOOP
      dbms_lob.freetemporary(g_pages(i));
    END LOOP;
    g_objects.delete;
    g_pages.delete;
    -- AW: Page-settings
    g_settings_per_page.delete;
    g_fonts.delete;
    g_used_fonts.delete;
    g_page_prcs.delete;
    IF g_images.count() > 0 THEN
      FOR i IN g_images.first .. g_images.last LOOP
        IF dbms_lob.istemporary(g_images(i).pixels) = 1 THEN
          dbms_lob.freetemporary(g_images(i).pixels);
        END IF;
      END LOOP;
      g_images.delete;
    END IF;
  END;
  --
  FUNCTION conv2uu(p_value NUMBER,
                   p_unit  VARCHAR2) RETURN NUMBER IS
    c_inch CONSTANT NUMBER := 25.40025;
  BEGIN
    RETURN round(CASE lower(p_unit) WHEN 'mm' THEN p_value * 72 / c_inch WHEN 'cm' THEN p_value * 720 / c_inch WHEN 'pt' THEN p_value -- also point
                 WHEN 'point' THEN p_value WHEN 'inch' THEN p_value * 72 WHEN 'in' THEN p_value * 72 -- also inch
                 WHEN 'pica' THEN p_value * 12 WHEN 'p' THEN p_value * 12 -- also pica
                 WHEN 'pc' THEN p_value * 12 -- also pica
                 WHEN 'em' THEN p_value * 12 -- also pica
                 WHEN 'px' THEN p_value -- pixel voorlopig op point zetten
                 WHEN 'px' THEN p_value * 0.8 -- pixel
                 ELSE NULL END, 3);
  END;
  --
  PROCEDURE set_page_size(p_width  NUMBER,
                          p_height NUMBER,
                          p_unit   VARCHAR2 := 'cm') IS
  BEGIN
    g_settings.page_width  := conv2uu(p_width, p_unit);
    g_settings.page_height := conv2uu(p_height, p_unit);
  END;
  --
  PROCEDURE set_page_format(p_format VARCHAR2 := 'A4') IS
  BEGIN
    CASE upper(p_format)
      WHEN 'A3' THEN
        set_page_size(420, 297, 'mm');
      WHEN 'A4' THEN
        set_page_size(297, 210, 'mm');
      WHEN 'A5' THEN
        set_page_size(210, 148, 'mm');
      WHEN 'A6' THEN
        set_page_size(148, 105, 'mm');
      WHEN 'LEGAL' THEN
        set_page_size(14, 8.5, 'in');
      WHEN 'LETTER' THEN
        set_page_size(11, 8.5, 'in');
      WHEN 'QUARTO' THEN
        set_page_size(11, 9, 'in');
      WHEN 'EXECUTIVE' THEN
        set_page_size(10.5, 7.25, 'in');
      ELSE
        NULL;
    END CASE;
  END;
  --
  PROCEDURE set_page_orientation(p_orientation VARCHAR2 := 'PORTRAIT') IS
    t_tmp NUMBER;
  BEGIN
    IF ((upper(p_orientation) IN ('L', 'LANDSCAPE') AND g_settings.page_height > g_settings.page_width) OR (upper(p_orientation) IN ('P', 'PORTRAIT') AND g_settings.page_height < g_settings.page_width)) THEN
      t_tmp                  := g_settings.page_width;
      g_settings.page_width  := g_settings.page_height;
      g_settings.page_height := t_tmp;
    END IF;
  END;
  --
  PROCEDURE set_margins(p_top    NUMBER := NULL,
                        p_left   NUMBER := NULL,
                        p_bottom NUMBER := NULL,
                        p_right  NUMBER := NULL,
                        p_unit   VARCHAR2 := 'cm') IS
    t_tmp NUMBER;
  BEGIN
    t_tmp := nvl(conv2uu(p_top, p_unit), -1);
    IF t_tmp < 0
       OR t_tmp > g_settings.page_height THEN
      t_tmp := conv2uu(3, 'cm');
    END IF;
    g_settings.margin_top := t_tmp;
    t_tmp                 := nvl(conv2uu(p_bottom, p_unit), -1);
    IF t_tmp < 0
       OR t_tmp > g_settings.page_height THEN
      t_tmp := conv2uu(4, 'cm');
    END IF;
    g_settings.margin_bottom := t_tmp;
    t_tmp                    := nvl(conv2uu(p_left, p_unit), -1);
    IF t_tmp < 0
       OR t_tmp > g_settings.page_width THEN
      t_tmp := conv2uu(1, 'cm');
    END IF;
    g_settings.margin_left := t_tmp;
    t_tmp                  := nvl(conv2uu(p_right, p_unit), -1);
    IF t_tmp < 0
       OR t_tmp > g_settings.page_width THEN
      t_tmp := conv2uu(1, 'cm');
    END IF;
    g_settings.margin_right := t_tmp;
    --
    IF g_settings.margin_top + g_settings.margin_bottom + conv2uu(1, 'cm') > g_settings.page_height THEN
      g_settings.margin_top    := 0;
      g_settings.margin_bottom := 0;
    END IF;
    IF g_settings.margin_left + g_settings.margin_right + conv2uu(1, 'cm') > g_settings.page_width THEN
      g_settings.margin_left  := 0;
      g_settings.margin_right := 0;
    END IF;
  END;
  --
  PROCEDURE set_info(p_title    VARCHAR2 := NULL,
                     p_author   VARCHAR2 := NULL,
                     p_subject  VARCHAR2 := NULL,
                     p_keywords VARCHAR2 := NULL) IS
  BEGIN
    g_info.title    := substr(p_title, 1, 1024);
    g_info.author   := substr(p_author, 1, 1024);
    g_info.subject  := substr(p_subject, 1, 1024);
    g_info.keywords := substr(p_keywords, 1, 16383);
  END;
  --
  PROCEDURE init IS
  BEGIN
    g_objects.delete;
    g_pages.delete;
    -- AW: Page-settings
    g_settings_per_page.delete;
    g_fonts.delete;
    g_used_fonts.delete;
    g_page_prcs.delete;
    g_images.delete;
    g_settings := NULL;
    g_current_font := NULL;
    g_x := NULL;
    g_y := NULL;
    g_info := NULL;
    g_page_nr := NULL;
    g_objects(0) := 0;
    init_core_fonts;
    set_page_format;
    set_page_orientation;
    set_margins;
  END;
  --
  FUNCTION get_pdf RETURN BLOB IS
  BEGIN
    finish_pdf;
    RETURN g_pdf_doc;
  END;
  --
  PROCEDURE save_pdf(p_dir      VARCHAR2 := 'MY_DIR',
                     p_filename VARCHAR2 := 'my.pdf',
                     p_freeblob BOOLEAN := TRUE) IS
    t_fh  utl_file.file_type;
    t_len PLS_INTEGER := 32767;
  BEGIN
    finish_pdf;
    t_fh := utl_file.fopen(p_dir, p_filename, 'wb');
    FOR i IN 0 .. trunc((dbms_lob.getlength(g_pdf_doc) - 1) / t_len) LOOP
      utl_file.put_raw(t_fh, dbms_lob.substr(g_pdf_doc, t_len, i * t_len + 1));
    END LOOP;
    utl_file.fclose(t_fh);
    IF p_freeblob THEN
      dbms_lob.freetemporary(g_pdf_doc);
    END IF;
  END;
  --
  PROCEDURE raw2page(p_txt RAW) IS
  BEGIN
    IF g_pages.count() = 0 THEN
      new_page;
    END IF;
    dbms_lob.append(g_pages(coalesce(g_page_nr, g_pages.count() - 1)), utl_raw.concat(p_txt, hextoraw('0D0A')));
  END;
  --
  PROCEDURE txt2page(p_txt VARCHAR2) IS
  BEGIN
    raw2page(utl_raw.cast_to_raw(p_txt));
  END;
  --
  PROCEDURE output_font_to_doc(p_output_to_doc BOOLEAN) IS
  BEGIN
    IF p_output_to_doc THEN
      txt2page('BT /F' || g_current_font || ' ' || to_char_round(g_fonts(g_current_font).fontsize) || ' Tf ET');
    END IF;
  END;
  --
  PROCEDURE set_font(p_index         PLS_INTEGER,
                     p_fontsize_pt   NUMBER,
                     p_output_to_doc BOOLEAN := TRUE) IS
  BEGIN
    IF p_index IS NOT NULL THEN
      g_used_fonts(p_index) := 0;
      g_fonts(p_index).fontsize := p_fontsize_pt;
      g_current_font_record.fontsize := p_fontsize_pt;
      IF NVL(g_current_font, -1) != p_index THEN
        -- aw set only if different
        g_current_font        := p_index;
        g_current_font_record := g_fonts(p_index);
      END IF;
      output_font_to_doc(p_output_to_doc);
    END IF;
  END;
  --
  FUNCTION set_font(p_fontname      VARCHAR2,
                    p_fontsize_pt   NUMBER,
                    p_output_to_doc BOOLEAN := TRUE) RETURN PLS_INTEGER IS
    t_fontname VARCHAR2(100);
  BEGIN
    IF p_fontname IS NULL THEN
      IF (g_current_font IS NOT NULL AND p_fontsize_pt != g_fonts(g_current_font).fontsize) THEN
        g_fonts(g_current_font).fontsize := p_fontsize_pt;
        g_current_font_record := g_fonts(g_current_font);
        output_font_to_doc(p_output_to_doc);
      END IF;
      RETURN g_current_font;
    END IF;
    --
    t_fontname := lower(p_fontname);
    FOR i IN g_fonts.first .. g_fonts.last LOOP
      IF lower(g_fonts(i).fontname) = t_fontname THEN
        EXIT WHEN g_current_font = i AND g_fonts(i).fontsize = p_fontsize_pt AND g_page_nr IS NULL;
        g_fonts(i).fontsize := coalesce(p_fontsize_pt, g_fonts(nvl(g_current_font, i)).fontsize, 12);
        g_current_font := i;
        g_current_font_record := g_fonts(i);
        g_used_fonts(i) := 0;
        output_font_to_doc(p_output_to_doc);
        RETURN g_current_font;
      END IF;
    END LOOP;
    RETURN NULL;
  END;
  --
  PROCEDURE set_font(p_fontname      VARCHAR2,
                     p_fontsize_pt   NUMBER,
                     p_output_to_doc BOOLEAN := TRUE) IS
    t_dummy PLS_INTEGER;
  BEGIN
    t_dummy := set_font(p_fontname, p_fontsize_pt, p_output_to_doc);
  END;
  --
  FUNCTION set_font(p_family        VARCHAR2,
                    p_style         VARCHAR2 := 'N',
                    p_fontsize_pt   NUMBER := NULL,
                    p_output_to_doc BOOLEAN := TRUE) RETURN PLS_INTEGER IS
    t_family VARCHAR2(100);
    t_style  VARCHAR2(100);
  BEGIN
    IF p_family IS NULL
       AND g_current_font IS NULL THEN
      RETURN NULL;
    END IF;
    IF p_family IS NULL
       AND p_style IS NULL
       AND p_fontsize_pt IS NULL THEN
      RETURN NULL;
    END IF;
    t_family := coalesce(lower(p_family), g_fonts(g_current_font).family);
    t_style  := upper(p_style);
  
    t_style := CASE t_style
                 WHEN 'NORMAL' THEN
                  'N'
                 WHEN 'REGULAR' THEN
                  'N'
                 WHEN 'BOLD' THEN
                  'B'
                 WHEN 'ITALIC' THEN
                  'I'
                 WHEN 'OBLIQUE' THEN
                  'I'
                 ELSE
                  t_style
               END;
    t_style := coalesce(t_style, CASE
                           WHEN g_current_font IS NULL THEN
                            'N'
                           ELSE
                            g_fonts(g_current_font).style
                         END);
    --
    FOR i IN g_fonts.first .. g_fonts.last LOOP
      IF (g_fonts(i).family = t_family AND g_fonts(i).style = t_style) THEN
        RETURN set_font(g_fonts(i).fontname, p_fontsize_pt, p_output_to_doc);
      END IF;
    END LOOP;
    RETURN NULL;
  END;
  --
  PROCEDURE set_font(p_family        VARCHAR2,
                     p_style         VARCHAR2 := 'N',
                     p_fontsize_pt   NUMBER := NULL,
                     p_output_to_doc BOOLEAN := TRUE) IS
    t_dummy PLS_INTEGER;
  BEGIN
    t_dummy := set_font(p_family, p_style, p_fontsize_pt, p_output_to_doc);
  END;
  --
  PROCEDURE new_page IS
  BEGIN
    g_pages(g_pages.count()) := NULL;
    g_settings_per_page(g_settings_per_page.count()) := g_settings;
    dbms_lob.createtemporary(g_pages(g_pages.count() - 1), TRUE);
    IF g_current_font IS NOT NULL
       AND g_pages.count() > 0 THEN
      txt2page('BT /F' || g_current_font || ' ' || to_char_round(g_fonts(g_current_font).fontsize) || ' Tf ET');
    END IF;
    g_x := NULL;
    g_y := NULL;
  END;
  --
  FUNCTION pdf_string(p_txt IN BLOB) RETURN BLOB IS
    t_rv  BLOB;
    t_ind INTEGER;
    TYPE tp_tab_raw IS TABLE OF RAW(1);
    tab_raw tp_tab_raw := tp_tab_raw(utl_raw.cast_to_raw('\'), utl_raw.cast_to_raw('('), utl_raw.cast_to_raw(')'));
  BEGIN
    t_rv := p_txt;
    FOR i IN tab_raw.first .. tab_raw.last LOOP
      t_ind := -1;
      LOOP
        t_ind := dbms_lob.instr(t_rv, tab_raw(i), t_ind + 2);
        EXIT WHEN t_ind <= 0;
        dbms_lob.copy(t_rv, t_rv, dbms_lob.lobmaxsize, t_ind + 1, t_ind);
        dbms_lob.copy(t_rv, utl_raw.cast_to_raw('\'), 1, t_ind, 1);
      END LOOP;
    END LOOP;
    RETURN t_rv;
  END;
  --
  FUNCTION txt2raw(p_txt VARCHAR2) RETURN RAW IS
    t_rv      RAW(32767);
    t_unicode PLS_INTEGER;
  BEGIN
    IF g_current_font IS NULL THEN
      set_font('helvetica');
    END IF;
    IF g_fonts(g_current_font).cid THEN
      FOR i IN 1 .. length(p_txt) LOOP
        t_unicode := utl_raw.cast_to_binary_integer(utl_raw.convert(utl_raw.cast_to_raw(substr(p_txt, i, 1)), 'AMERICAN_AMERICA.AL16UTF16', sys_context('userenv', 'LANGUAGE') -- ???? font characterset ?????
                                                                    ));
        IF g_fonts(g_current_font).flags = 4 -- a symbolic font
         THEN
          -- assume code 32, space maps to the first code from the font
          t_unicode := g_fonts(g_current_font).code2glyph.first + t_unicode - 32;
        END IF;
        IF g_current_font_record.code2glyph.exists(t_unicode) THEN
          g_fonts(g_current_font).used_chars(g_current_font_record.code2glyph(t_unicode)) := 0;
          t_rv := utl_raw.concat(t_rv, utl_raw.cast_to_raw(to_char(g_current_font_record.code2glyph(t_unicode), 'FM0XXX')));
        ELSE
          t_rv := utl_raw.concat(t_rv, utl_raw.cast_to_raw('0000'));
        END IF;
      END LOOP;
      t_rv := utl_raw.concat(utl_raw.cast_to_raw('<'), t_rv, utl_raw.cast_to_raw('>'));
    ELSE
      t_rv := utl_raw.convert(utl_raw.cast_to_raw(p_txt), g_fonts(g_current_font).charset, sys_context('userenv', 'LANGUAGE'));
      FOR i IN 1 .. utl_raw.length(t_rv) LOOP
        g_fonts(g_current_font).used_chars(raw2num(t_rv, i, 1)) := 0;
      END LOOP;
      t_rv := utl_raw.concat(utl_raw.cast_to_raw('('), pdf_string(t_rv), utl_raw.cast_to_raw(')'));
    END IF;
    RETURN t_rv;
  END;
  --
  PROCEDURE put_raw(p_x                NUMBER,
                    p_y                NUMBER,
                    p_txt              RAW,
                    p_degrees_rotation NUMBER := NULL) IS
    c_pi CONSTANT NUMBER := 3.14159265358979323846264338327950288419716939937510;
    t_tmp VARCHAR2(32767);
    t_sin NUMBER;
    t_cos NUMBER;
  BEGIN
    t_tmp := to_char_round(p_x) || ' ' || to_char_round(p_y);
    IF p_degrees_rotation IS NULL THEN
      t_tmp := t_tmp || ' Td ';
    ELSE
      t_sin := sin(p_degrees_rotation / 180 * c_pi);
      t_cos := cos(p_degrees_rotation / 180 * c_pi);
      t_tmp := to_char_round(t_cos, 5) || ' ' || t_tmp;
      t_tmp := to_char_round(-t_sin, 5) || ' ' || t_tmp;
      t_tmp := to_char_round(t_sin, 5) || ' ' || t_tmp;
      t_tmp := to_char_round(t_cos, 5) || ' ' || t_tmp;
      t_tmp := t_tmp || ' Tm ';
    END IF;
    raw2page(utl_raw.concat(utl_raw.cast_to_raw('BT ' || t_tmp), p_txt, utl_raw.cast_to_raw(' Tj ET')));
  END;
  --
  PROCEDURE put_txt(p_x                NUMBER,
                    p_y                NUMBER,
                    p_txt              VARCHAR2,
                    p_degrees_rotation NUMBER := NULL) IS
  BEGIN
    IF p_txt IS NOT NULL THEN
      put_raw(p_x, p_y, txt2raw(p_txt), p_degrees_rotation);
    END IF;
  END;
  --
  FUNCTION str_len(p_txt IN VARCHAR2) RETURN NUMBER IS
    t_width NUMBER;
    t_char  PLS_INTEGER;
    t_rtxt  RAW(32767);
    t_tmp   NUMBER;
    --t_font tp_font;
  BEGIN
    IF p_txt IS NULL THEN
      RETURN 0;
    END IF;
    --
    t_width := 0;
    IF g_current_font_record.cid THEN
      t_rtxt := utl_raw.convert(utl_raw.cast_to_raw(p_txt), 'AMERICAN_AMERICA.AL16UTF16' -- 16 bit font => 2 bytes per char
                               , sys_context('userenv', 'LANGUAGE') -- ???? font characterset ?????
                                );
      FOR i IN 1 .. utl_raw.length(t_rtxt) / 2 LOOP
        t_char := to_number(utl_raw.substr(t_rtxt, i * 2 - 1, 2), 'xxxx');
        IF g_current_font_record.flags = 4 THEN
          -- assume code 32, space maps to the first code from the font
          t_char := g_current_font_record.code2glyph.first + t_char - 32;
        END IF;
        IF (g_current_font_record.code2glyph.exists(t_char) AND g_current_font_record.hmetrics.exists(g_current_font_record.code2glyph(t_char))) THEN
          t_tmp := g_current_font_record.hmetrics(g_current_font_record.code2glyph(t_char));
        ELSE
          t_tmp := g_current_font_record.hmetrics(g_current_font_record.hmetrics.last());
        END IF;
        t_width := t_width + t_tmp;
      END LOOP;
      t_width := t_width * g_current_font_record.unit_norm;
      t_width := t_width * g_current_font_record.fontsize / 1000;
    ELSE
      t_rtxt := utl_raw.convert(utl_raw.cast_to_raw(p_txt), g_current_font_record.charset -- should be an 8 bit font
                               , sys_context('userenv', 'LANGUAGE'));
      FOR i IN 1 .. utl_raw.length(t_rtxt) LOOP
        t_char  := to_number(utl_raw.substr(t_rtxt, i, 1), 'xx');
        t_width := t_width + g_current_font_record.char_width_tab(t_char);
      END LOOP;
      t_width := t_width * g_current_font_record.fontsize / 1000;
    END IF;
    RETURN t_width;
  END;
  --
  PROCEDURE WRITE(p_txt         IN VARCHAR2,
                  p_x           IN NUMBER := NULL,
                  p_y           IN NUMBER := NULL,
                  p_line_height IN NUMBER := NULL,
                  p_start       IN NUMBER := NULL -- left side of the available text box
                 ,
                  p_width       IN NUMBER := NULL -- width of the available text box
                 ,
                  p_alignment   IN VARCHAR2 := NULL) IS
    t_line_height NUMBER;
    t_x           NUMBER;
    t_y           NUMBER;
    t_start       NUMBER;
    t_width       NUMBER;
    t_len         NUMBER;
    t_cnt         PLS_INTEGER;
    t_ind         PLS_INTEGER;
    t_alignment   VARCHAR2(100);
  BEGIN
    IF p_txt IS NULL THEN
      RETURN;
    END IF;
    --
    IF g_current_font IS NULL THEN
      set_font('helvetica');
    END IF;
    --
    t_line_height := nvl(p_line_height, g_fonts(g_current_font).fontsize);
    IF (t_line_height < g_fonts(g_current_font).fontsize OR t_line_height > (g_settings.page_height - g_settings.margin_top - t_line_height) / 4) THEN
      t_line_height := g_fonts(g_current_font).fontsize;
    END IF;
    t_start := nvl(p_start, g_settings.margin_left);
    IF (t_start < g_settings.margin_left OR t_start > g_settings.page_width - g_settings.margin_right - g_settings.margin_left) THEN
      t_start := g_settings.margin_left;
    END IF;
    t_width := nvl(p_width, g_settings.page_width - g_settings.margin_right - g_settings.margin_left);
    IF (t_width < str_len('   ') OR t_width > g_settings.page_width - g_settings.margin_right - g_settings.margin_left) THEN
      t_width := g_settings.page_width - g_settings.margin_right - g_settings.margin_left;
    END IF;
    t_x := coalesce(p_x, g_x, g_settings.margin_left);
    t_y := coalesce(p_y, g_y, g_settings.page_height - g_settings.margin_top - t_line_height);
    IF t_y < 0 THEN
      t_y := coalesce(g_y, g_settings.page_height - g_settings.margin_top - t_line_height) - t_line_height;
    END IF;
    IF t_x > t_start + t_width THEN
      t_x := t_start;
      t_y := t_y - t_line_height;
    ELSIF t_x < t_start THEN
      t_x := t_start;
    END IF;
    IF t_y < g_settings.margin_bottom THEN
      new_page;
      t_x := t_start;
      t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
    END IF;
    --
    t_ind := instr(p_txt, chr(10));
    IF t_ind > 0 THEN
      g_x := t_x;
      g_y := t_y;
      WRITE(rtrim(substr(p_txt, 1, t_ind - 1), chr(13)), t_x, t_y, t_line_height, t_start, t_width, p_alignment);
      t_y := g_y - t_line_height;
      IF t_y < g_settings.margin_bottom THEN
        new_page;
        t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
      END IF;
      g_x := t_start;
      g_y := t_y;
      WRITE(substr(p_txt, t_ind + 1), t_start, t_y, t_line_height, t_start, t_width, p_alignment);
      RETURN;
    END IF;
    --
    t_len := str_len(p_txt);
    IF t_len <= t_width - t_x + t_start THEN
      t_alignment := lower(substr(p_alignment, 1, 100));
      IF instr(t_alignment, 'right') > 0
         OR instr(t_alignment, 'end') > 0 THEN
        t_x := t_start + t_width - t_len;
      ELSIF instr(t_alignment, 'center') > 0 THEN
        t_x := (t_width + t_x + t_start - t_len) / 2;
      END IF;
      put_txt(t_x, t_y, p_txt);
      g_x := t_x + t_len + str_len(' ');
      g_y := t_y;
      RETURN;
    END IF;
    --
    t_cnt := 0;
    WHILE (instr(p_txt, ' ', 1, t_cnt + 1) > 0 AND str_len(substr(p_txt, 1, instr(p_txt, ' ', 1, t_cnt + 1) - 1)) <= t_width - t_x + t_start) LOOP
      t_cnt := t_cnt + 1;
    END LOOP;
    IF t_cnt > 0 THEN
      t_ind := instr(p_txt, ' ', 1, t_cnt);
      WRITE(substr(p_txt, 1, t_ind - 1), t_x, t_y, t_line_height, t_start, t_width, p_alignment);
      t_y := t_y - t_line_height;
      IF t_y < g_settings.margin_bottom THEN
        new_page;
        t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
      END IF;
      WRITE(substr(p_txt, t_ind + 1), t_start, t_y, t_line_height, t_start, t_width, p_alignment);
      RETURN;
    END IF;
    --
    IF t_x > t_start
       AND t_len < t_width THEN
      t_y := t_y - t_line_height;
      IF t_y < g_settings.margin_bottom THEN
        new_page;
        t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
      END IF;
      WRITE(p_txt, t_start, t_y, t_line_height, t_start, t_width, p_alignment);
    ELSE
      IF length(p_txt) = 1 THEN
        IF t_x > t_start THEN
          t_y := t_y - t_line_height;
          IF t_y < g_settings.margin_bottom THEN
            new_page;
            t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
          END IF;
        END IF;
        WRITE(p_txt, t_x, t_y, t_line_height, t_start, t_len);
      ELSE
        t_ind := 2; -- start with 2 to make sure we get amaller string!
        WHILE str_len(substr(p_txt, 1, t_ind)) <= t_width - t_x + t_start LOOP
          t_ind := t_ind + 1;
        END LOOP;
        WRITE(substr(p_txt, 1, t_ind - 1), t_x, t_y, t_line_height, t_start, t_width, p_alignment);
        t_y := t_y - t_line_height;
        IF t_y < g_settings.margin_bottom THEN
          new_page;
          t_y := g_settings.page_height - g_settings.margin_top - t_line_height;
        END IF;
        WRITE(substr(p_txt, t_ind), t_start, t_y, t_line_height, t_start, t_width, p_alignment);
      END IF;
    END IF;
  END;
  --
  FUNCTION load_ttf_font(p_font     BLOB,
                         p_encoding VARCHAR2 := 'WINDOWS-1252',
                         p_embed    BOOLEAN := FALSE,
                         p_compress BOOLEAN := TRUE,
                         p_offset   NUMBER := 1) RETURN PLS_INTEGER IS
    this_font tp_font;
    TYPE tp_font_table IS RECORD(
      offset PLS_INTEGER,
      length PLS_INTEGER);
    TYPE tp_tables IS TABLE OF tp_font_table INDEX BY VARCHAR2(4);
    t_tables    tp_tables;
    t_tag       VARCHAR2(4);
    t_blob      BLOB;
    t_offset    PLS_INTEGER;
    nr_hmetrics PLS_INTEGER;
    SUBTYPE tp_glyphname IS VARCHAR2(250);
    TYPE tp_glyphnames IS TABLE OF tp_glyphname INDEX BY PLS_INTEGER;
    t_glyphnames tp_glyphnames;
    t_glyph2name tp_pls_tab;
    t_font_ind   PLS_INTEGER;
  BEGIN
    IF dbms_lob.substr(p_font, 4, p_offset) != hextoraw('00010000') --  OpenType Font
     THEN
      RETURN NULL;
    END IF;
    FOR i IN 1 .. blob2num(p_font, 2, p_offset + 4) LOOP
      t_tag := utl_raw.cast_to_varchar2(dbms_lob.substr(p_font, 4, p_offset - 4 + i * 16));
      t_tables(t_tag).offset := blob2num(p_font, 4, p_offset + 4 + i * 16) + 1;
      t_tables(t_tag).length := blob2num(p_font, 4, p_offset + 8 + i * 16);
    END LOOP;
    --
    IF (NOT t_tables.exists('cmap') OR NOT t_tables.exists('glyf') OR NOT t_tables.exists('head') OR NOT t_tables.exists('hhea') OR NOT t_tables.exists('hmtx') OR NOT t_tables.exists('loca') OR NOT t_tables.exists('maxp') OR NOT t_tables.exists('name') OR NOT t_tables.exists('post')) THEN
      RETURN NULL;
    END IF;
    --
    dbms_lob.createtemporary(t_blob, TRUE);
    dbms_lob.copy(t_blob, p_font, t_tables('maxp').length, 1, t_tables('maxp').offset);
    this_font.numGlyphs := blob2num(t_blob, 2, 5);
    --
    dbms_lob.copy(t_blob, p_font, t_tables('cmap').length, 1, t_tables('cmap').offset);
    FOR i IN 0 .. blob2num(t_blob, 2, 3) - 1 LOOP
      IF (dbms_lob.substr(t_blob, 2, 5 + i * 8) = hextoraw('0003') -- Windows
         AND dbms_lob.substr(t_blob, 2, 5 + i * 8 + 2) IN (hextoraw('0000') -- Symbol
                                                           , hextoraw('0001') -- Unicode BMP (UCS-2)
                                                            )) THEN
        IF dbms_lob.substr(t_blob, 2, 5 + i * 8 + 2) = hextoraw('0000') -- Symbol
         THEN
          this_font.flags := 4; -- symbolic
        ELSE
          this_font.flags := 32; -- non-symbolic
        END IF;
        t_offset := blob2num(t_blob, 4, 5 + i * 8 + 4) + 1;
        IF dbms_lob.substr(t_blob, 2, t_offset) != hextoraw('0004') THEN
          RETURN NULL;
        END IF;
        DECLARE
          t_seg_cnt            PLS_INTEGER;
          t_end_offs           PLS_INTEGER;
          t_start_offs         PLS_INTEGER;
          t_idDelta_offs       PLS_INTEGER;
          t_idRangeOffset_offs PLS_INTEGER;
          t_tmp                PLS_INTEGER;
          t_start              PLS_INTEGER;
        BEGIN
          t_seg_cnt            := blob2num(t_blob, 2, t_offset + 6) / 2;
          t_end_offs           := t_offset + 14;
          t_start_offs         := t_end_offs + t_seg_cnt * 2 + 2;
          t_idDelta_offs       := t_start_offs + t_seg_cnt * 2;
          t_idRangeOffset_offs := t_idDelta_offs + t_seg_cnt * 2;
          FOR seg IN 0 .. t_seg_cnt - 1 LOOP
            t_tmp := blob2num(t_blob, 2, t_idRangeOffset_offs + seg * 2);
            IF t_tmp = 0 THEN
              t_tmp := blob2num(t_blob, 2, t_idDelta_offs + seg * 2);
              FOR c IN blob2num(t_blob, 2, t_start_offs + seg * 2) .. blob2num(t_blob, 2, t_end_offs + seg * 2) LOOP
                this_font.code2glyph(c) := MOD(c + t_tmp, 65536);
              END LOOP;
            ELSE
              t_start := blob2num(t_blob, 2, t_start_offs + seg * 2);
              FOR c IN t_start .. blob2num(t_blob, 2, t_end_offs + seg * 2) LOOP
                this_font.code2glyph(c) := blob2num(t_blob, 2, t_idRangeOffset_offs + t_tmp + (seg + c - t_start) * 2);
              END LOOP;
            END IF;
          END LOOP;
        END;
        EXIT;
      END IF;
    END LOOP;
    --
    t_glyphnames(0) := '.notdef';
    t_glyphnames(1) := '.null';
    t_glyphnames(2) := 'nonmarkingreturn';
    t_glyphnames(3) := 'space';
    t_glyphnames(4) := 'exclam';
    t_glyphnames(5) := 'quotedbl';
    t_glyphnames(6) := 'numbersign';
    t_glyphnames(7) := 'dollar';
    t_glyphnames(8) := 'percent';
    t_glyphnames(9) := 'ampersand';
    t_glyphnames(10) := 'quotesingle';
    t_glyphnames(11) := 'parenleft';
    t_glyphnames(12) := 'parenright';
    t_glyphnames(13) := 'asterisk';
    t_glyphnames(14) := 'plus';
    t_glyphnames(15) := 'comma';
    t_glyphnames(16) := 'hyphen';
    t_glyphnames(17) := 'period';
    t_glyphnames(18) := 'slash';
    t_glyphnames(19) := 'zero';
    t_glyphnames(20) := 'one';
    t_glyphnames(21) := 'two';
    t_glyphnames(22) := 'three';
    t_glyphnames(23) := 'four';
    t_glyphnames(24) := 'five';
    t_glyphnames(25) := 'six';
    t_glyphnames(26) := 'seven';
    t_glyphnames(27) := 'eight';
    t_glyphnames(28) := 'nine';
    t_glyphnames(29) := 'colon';
    t_glyphnames(30) := 'semicolon';
    t_glyphnames(31) := 'less';
    t_glyphnames(32) := 'equal';
    t_glyphnames(33) := 'greater';
    t_glyphnames(34) := 'question';
    t_glyphnames(35) := 'at';
    t_glyphnames(36) := 'A';
    t_glyphnames(37) := 'B';
    t_glyphnames(38) := 'C';
    t_glyphnames(39) := 'D';
    t_glyphnames(40) := 'E';
    t_glyphnames(41) := 'F';
    t_glyphnames(42) := 'G';
    t_glyphnames(43) := 'H';
    t_glyphnames(44) := 'I';
    t_glyphnames(45) := 'J';
    t_glyphnames(46) := 'K';
    t_glyphnames(47) := 'L';
    t_glyphnames(48) := 'M';
    t_glyphnames(49) := 'N';
    t_glyphnames(50) := 'O';
    t_glyphnames(51) := 'P';
    t_glyphnames(52) := 'Q';
    t_glyphnames(53) := 'R';
    t_glyphnames(54) := 'S';
    t_glyphnames(55) := 'T';
    t_glyphnames(56) := 'U';
    t_glyphnames(57) := 'V';
    t_glyphnames(58) := 'W';
    t_glyphnames(59) := 'X';
    t_glyphnames(60) := 'Y';
    t_glyphnames(61) := 'Z';
    t_glyphnames(62) := 'bracketleft';
    t_glyphnames(63) := 'backslash';
    t_glyphnames(64) := 'bracketright';
    t_glyphnames(65) := 'asciicircum';
    t_glyphnames(66) := 'underscore';
    t_glyphnames(67) := 'grave';
    t_glyphnames(68) := 'a';
    t_glyphnames(69) := 'b';
    t_glyphnames(70) := 'c';
    t_glyphnames(71) := 'd';
    t_glyphnames(72) := 'e';
    t_glyphnames(73) := 'f';
    t_glyphnames(74) := 'g';
    t_glyphnames(75) := 'h';
    t_glyphnames(76) := 'i';
    t_glyphnames(77) := 'j';
    t_glyphnames(78) := 'k';
    t_glyphnames(79) := 'l';
    t_glyphnames(80) := 'm';
    t_glyphnames(81) := 'n';
    t_glyphnames(82) := 'o';
    t_glyphnames(83) := 'p';
    t_glyphnames(84) := 'q';
    t_glyphnames(85) := 'r';
    t_glyphnames(86) := 's';
    t_glyphnames(87) := 't';
    t_glyphnames(88) := 'u';
    t_glyphnames(89) := 'v';
    t_glyphnames(90) := 'w';
    t_glyphnames(91) := 'x';
    t_glyphnames(92) := 'y';
    t_glyphnames(93) := 'z';
    t_glyphnames(94) := 'braceleft';
    t_glyphnames(95) := 'bar';
    t_glyphnames(96) := 'braceright';
    t_glyphnames(97) := 'asciitilde';
    t_glyphnames(98) := 'Adieresis';
    t_glyphnames(99) := 'Aring';
    t_glyphnames(100) := 'Ccedilla';
    t_glyphnames(101) := 'Eacute';
    t_glyphnames(102) := 'Ntilde';
    t_glyphnames(103) := 'Odieresis';
    t_glyphnames(104) := 'Udieresis';
    t_glyphnames(105) := 'aacute';
    t_glyphnames(106) := 'agrave';
    t_glyphnames(107) := 'acircumflex';
    t_glyphnames(108) := 'adieresis';
    t_glyphnames(109) := 'atilde';
    t_glyphnames(110) := 'aring';
    t_glyphnames(111) := 'ccedilla';
    t_glyphnames(112) := 'eacute';
    t_glyphnames(113) := 'egrave';
    t_glyphnames(114) := 'ecircumflex';
    t_glyphnames(115) := 'edieresis';
    t_glyphnames(116) := 'iacute';
    t_glyphnames(117) := 'igrave';
    t_glyphnames(118) := 'icircumflex';
    t_glyphnames(119) := 'idieresis';
    t_glyphnames(120) := 'ntilde';
    t_glyphnames(121) := 'oacute';
    t_glyphnames(122) := 'ograve';
    t_glyphnames(123) := 'ocircumflex';
    t_glyphnames(124) := 'odieresis';
    t_glyphnames(125) := 'otilde';
    t_glyphnames(126) := 'uacute';
    t_glyphnames(127) := 'ugrave';
    t_glyphnames(128) := 'ucircumflex';
    t_glyphnames(129) := 'udieresis';
    t_glyphnames(130) := 'dagger';
    t_glyphnames(131) := 'degree';
    t_glyphnames(132) := 'cent';
    t_glyphnames(133) := 'sterling';
    t_glyphnames(134) := 'section';
    t_glyphnames(135) := 'bullet';
    t_glyphnames(136) := 'paragraph';
    t_glyphnames(137) := 'germandbls';
    t_glyphnames(138) := 'registered';
    t_glyphnames(139) := 'copyright';
    t_glyphnames(140) := 'trademark';
    t_glyphnames(141) := 'acute';
    t_glyphnames(142) := 'dieresis';
    t_glyphnames(143) := 'notequal';
    t_glyphnames(144) := 'AE';
    t_glyphnames(145) := 'Oslash';
    t_glyphnames(146) := 'infinity';
    t_glyphnames(147) := 'plusminus';
    t_glyphnames(148) := 'lessequal';
    t_glyphnames(149) := 'greaterequal';
    t_glyphnames(150) := 'yen';
    t_glyphnames(151) := 'mu';
    t_glyphnames(152) := 'partialdiff';
    t_glyphnames(153) := 'summation';
    t_glyphnames(154) := 'product';
    t_glyphnames(155) := 'pi';
    t_glyphnames(156) := 'integral';
    t_glyphnames(157) := 'ordfeminine';
    t_glyphnames(158) := 'ordmasculine';
    t_glyphnames(159) := 'Omega';
    t_glyphnames(160) := 'ae';
    t_glyphnames(161) := 'oslash';
    t_glyphnames(162) := 'questiondown';
    t_glyphnames(163) := 'exclamdown';
    t_glyphnames(164) := 'logicalnot';
    t_glyphnames(165) := 'radical';
    t_glyphnames(166) := 'florin';
    t_glyphnames(167) := 'approxequal';
    t_glyphnames(168) := 'Delta';
    t_glyphnames(169) := 'guillemotleft';
    t_glyphnames(170) := 'guillemotright';
    t_glyphnames(171) := 'ellipsis';
    t_glyphnames(172) := 'nonbreakingspace';
    t_glyphnames(173) := 'Agrave';
    t_glyphnames(174) := 'Atilde';
    t_glyphnames(175) := 'Otilde';
    t_glyphnames(176) := 'OE';
    t_glyphnames(177) := 'oe';
    t_glyphnames(178) := 'endash';
    t_glyphnames(179) := 'emdash';
    t_glyphnames(180) := 'quotedblleft';
    t_glyphnames(181) := 'quotedblright';
    t_glyphnames(182) := 'quoteleft';
    t_glyphnames(183) := 'quoteright';
    t_glyphnames(184) := 'divide';
    t_glyphnames(185) := 'lozenge';
    t_glyphnames(186) := 'ydieresis';
    t_glyphnames(187) := 'Ydieresis';
    t_glyphnames(188) := 'fraction';
    t_glyphnames(189) := 'currency';
    t_glyphnames(190) := 'guilsinglleft';
    t_glyphnames(191) := 'guilsinglright';
    t_glyphnames(192) := 'fi';
    t_glyphnames(193) := 'fl';
    t_glyphnames(194) := 'daggerdbl';
    t_glyphnames(195) := 'periodcentered';
    t_glyphnames(196) := 'quotesinglbase';
    t_glyphnames(197) := 'quotedblbase';
    t_glyphnames(198) := 'perthousand';
    t_glyphnames(199) := 'Acircumflex';
    t_glyphnames(200) := 'Ecircumflex';
    t_glyphnames(201) := 'Aacute';
    t_glyphnames(202) := 'Edieresis';
    t_glyphnames(203) := 'Egrave';
    t_glyphnames(204) := 'Iacute';
    t_glyphnames(205) := 'Icircumflex';
    t_glyphnames(206) := 'Idieresis';
    t_glyphnames(207) := 'Igrave';
    t_glyphnames(208) := 'Oacute';
    t_glyphnames(209) := 'Ocircumflex';
    t_glyphnames(210) := 'apple';
    t_glyphnames(211) := 'Ograve';
    t_glyphnames(212) := 'Uacute';
    t_glyphnames(213) := 'Ucircumflex';
    t_glyphnames(214) := 'Ugrave';
    t_glyphnames(215) := 'dotlessi';
    t_glyphnames(216) := 'circumflex';
    t_glyphnames(217) := 'tilde';
    t_glyphnames(218) := 'macron';
    t_glyphnames(219) := 'breve';
    t_glyphnames(220) := 'dotaccent';
    t_glyphnames(221) := 'ring';
    t_glyphnames(222) := 'cedilla';
    t_glyphnames(223) := 'hungarumlaut';
    t_glyphnames(224) := 'ogonek';
    t_glyphnames(225) := 'caron';
    t_glyphnames(226) := 'Lslash';
    t_glyphnames(227) := 'lslash';
    t_glyphnames(228) := 'Scaron';
    t_glyphnames(229) := 'scaron';
    t_glyphnames(230) := 'Zcaron';
    t_glyphnames(231) := 'zcaron';
    t_glyphnames(232) := 'brokenbar';
    t_glyphnames(233) := 'Eth';
    t_glyphnames(234) := 'eth';
    t_glyphnames(235) := 'Yacute';
    t_glyphnames(236) := 'yacute';
    t_glyphnames(237) := 'Thorn';
    t_glyphnames(238) := 'thorn';
    t_glyphnames(239) := 'minus';
    t_glyphnames(240) := 'multiply';
    t_glyphnames(241) := 'onesuperior';
    t_glyphnames(242) := 'twosuperior';
    t_glyphnames(243) := 'threesuperior';
    t_glyphnames(244) := 'onehalf';
    t_glyphnames(245) := 'onequarter';
    t_glyphnames(246) := 'threequarters';
    t_glyphnames(247) := 'franc';
    t_glyphnames(248) := 'Gbreve';
    t_glyphnames(249) := 'gbreve';
    t_glyphnames(250) := 'Idotaccent';
    t_glyphnames(251) := 'Scedilla';
    t_glyphnames(252) := 'scedilla';
    t_glyphnames(253) := 'Cacute';
    t_glyphnames(254) := 'cacute';
    t_glyphnames(255) := 'Ccaron';
    t_glyphnames(256) := 'ccaron';
    t_glyphnames(257) := 'dcroat';
    --
    dbms_lob.copy(t_blob, p_font, t_tables('post').length, 1, t_tables('post').offset);
    this_font.italic_angle := to_short(dbms_lob.substr(t_blob, 2, 5)) + to_short(dbms_lob.substr(t_blob, 2, 7)) / 65536;
    CASE rawtohex(dbms_lob.substr(t_blob, 4, 1))
      WHEN '00010000' THEN
        FOR g IN 0 .. 257 LOOP
          t_glyph2name(g) := g;
        END LOOP;
      WHEN '00020000' THEN
        t_offset := blob2num(t_blob, 2, 33) * 2 + 35;
        WHILE nvl(blob2num(t_blob, 1, t_offset), 0) > 0 LOOP
          t_glyphnames(t_glyphnames.count) := utl_raw.cast_to_varchar2(dbms_lob.substr(t_blob, blob2num(t_blob, 1, t_offset), t_offset + 1));
          t_offset := t_offset + blob2num(t_blob, 1, t_offset) + 1;
        END LOOP;
        FOR g IN 0 .. blob2num(t_blob, 2, 33) - 1 LOOP
          t_glyph2name(g) := blob2num(t_blob, 2, 35 + 2 * g);
        END LOOP;
      WHEN '00025000' THEN
        FOR g IN 0 .. blob2num(t_blob, 2, 33) - 1 LOOP
          t_offset := blob2num(t_blob, 1, 35 + g);
          IF t_offset > 127 THEN
            t_glyph2name(g) := g - t_offset;
          ELSE
            t_glyph2name(g) := g + t_offset;
          END IF;
        END LOOP;
      WHEN '00030000' THEN
        t_glyphnames.delete;
      ELSE
        dbms_output.put_line('no post ' || dbms_lob.substr(t_blob, 4, 1));
    END CASE;
    --
    dbms_lob.copy(t_blob, p_font, t_tables('head').length, 1, t_tables('head').offset);
    IF dbms_lob.substr(t_blob, 4, 13) = hextoraw('5F0F3CF5') -- magic
     THEN
      DECLARE
        t_tmp PLS_INTEGER := blob2num(t_blob, 2, 45);
      BEGIN
        IF bitand(t_tmp, 1) = 1 THEN
          this_font.style := 'B';
        END IF;
        IF bitand(t_tmp, 2) = 2 THEN
          this_font.style := this_font.style || 'I';
          this_font.flags := this_font.flags + 64;
        END IF;
        this_font.style            := nvl(this_font.style, 'N');
        this_font.unit_norm        := 1000 / blob2num(t_blob, 2, 19);
        this_font.bb_xmin          := to_short(dbms_lob.substr(t_blob, 2, 37), this_font.unit_norm);
        this_font.bb_ymin          := to_short(dbms_lob.substr(t_blob, 2, 39), this_font.unit_norm);
        this_font.bb_xmax          := to_short(dbms_lob.substr(t_blob, 2, 41), this_font.unit_norm);
        this_font.bb_ymax          := to_short(dbms_lob.substr(t_blob, 2, 43), this_font.unit_norm);
        this_font.indexToLocFormat := blob2num(t_blob, 2, 51); -- 0 for short offsets, 1 for long
      END;
    END IF;
    --
    dbms_lob.copy(t_blob, p_font, t_tables('hhea').length, 1, t_tables('hhea').offset);
    IF dbms_lob.substr(t_blob, 4, 1) = hextoraw('00010000') -- version 1.0
     THEN
      this_font.ascent    := to_short(dbms_lob.substr(t_blob, 2, 5), this_font.unit_norm);
      this_font.descent   := to_short(dbms_lob.substr(t_blob, 2, 7), this_font.unit_norm);
      this_font.capheight := this_font.ascent;
      nr_hmetrics         := blob2num(t_blob, 2, 35);
    END IF;
    --
    dbms_lob.copy(t_blob, p_font, t_tables('hmtx').length, 1, t_tables('hmtx').offset);
    FOR j IN 0 .. nr_hmetrics - 1 LOOP
      this_font.hmetrics(j) := blob2num(t_blob, 2, 1 + 4 * j);
    END LOOP;
    --
    dbms_lob.copy(t_blob, p_font, t_tables('name').length, 1, t_tables('name').offset);
    IF dbms_lob.substr(t_blob, 2, 1) = hextoraw('0000') -- format 0
     THEN
      t_offset := blob2num(t_blob, 2, 5) + 1;
      FOR j IN 0 .. blob2num(t_blob, 2, 3) - 1 LOOP
        IF (dbms_lob.substr(t_blob, 2, 7 + j * 12) = hextoraw('0003') -- Windows
           AND dbms_lob.substr(t_blob, 2, 11 + j * 12) = hextoraw('0409') -- English United States
           ) THEN
          CASE rawtohex(dbms_lob.substr(t_blob, 2, 13 + j * 12))
            WHEN '0001' THEN
              this_font.family := utl_i18n.raw_to_char(dbms_lob.substr(t_blob, blob2num(t_blob, 2, 15 + j * 12), t_offset + blob2num(t_blob, 2, 17 + j * 12)), 'AL16UTF16');
            WHEN '0006' THEN
              this_font.name := utl_i18n.raw_to_char(dbms_lob.substr(t_blob, blob2num(t_blob, 2, 15 + j * 12), t_offset + blob2num(t_blob, 2, 17 + j * 12)), 'AL16UTF16');
            ELSE
              NULL;
          END CASE;
        END IF;
      END LOOP;
    END IF;
    --
    IF this_font.italic_angle != 0 THEN
      this_font.flags := this_font.flags + 64;
    END IF;
    this_font.subtype       := 'TrueType';
    this_font.stemv         := 50;
    this_font.family        := lower(this_font.family);
    this_font.encoding      := utl_i18n.map_charset(p_encoding, utl_i18n.generic_context, utl_i18n.iana_to_oracle);
    this_font.encoding      := nvl(this_font.encoding, upper(p_encoding));
    this_font.charset       := sys_context('userenv', 'LANGUAGE');
    this_font.charset       := substr(this_font.charset, 1, instr(this_font.charset, '.')) || this_font.encoding;
    this_font.cid           := upper(p_encoding) IN ('CID', 'AL16UTF16', 'UTF', 'UNICODE');
    this_font.fontname      := this_font.name;
    this_font.compress_font := p_compress;
    --
    IF (p_embed OR this_font.cid)
       AND t_tables.exists('OS/2') THEN
      dbms_lob.copy(t_blob, p_font, t_tables('OS/2').length, 1, t_tables('OS/2').offset);
      IF blob2num(t_blob, 2, 9) != 2 THEN
        this_font.fontfile2  := p_font;
        this_font.ttf_offset := p_offset;
        this_font.name       := dbms_random.string('u', 6) || '+' || this_font.name;
        --
        t_blob := dbms_lob.substr(p_font, t_tables('loca').length, t_tables('loca').offset);
        DECLARE
          t_size PLS_INTEGER := 2 + this_font.indexToLocFormat * 2; -- 0 for short offsets, 1 for long
        BEGIN
          FOR i IN 0 .. this_font.numGlyphs LOOP
            this_font.loca(i) := blob2num(t_blob, t_size, 1 + i * t_size);
          END LOOP;
        END;
      END IF;
    END IF;
    --
    IF NOT this_font.cid THEN
      IF this_font.flags = 4 -- a symbolic font
       THEN
        DECLARE
          t_real PLS_INTEGER;
        BEGIN
          FOR t_code IN 32 .. 255 LOOP
            t_real := this_font.code2glyph.first + t_code - 32; -- assume code 32, space maps to the first code from the font
            IF this_font.code2glyph.exists(t_real) THEN
              this_font.first_char := least(nvl(this_font.first_char, 255), t_code);
              this_font.last_char  := t_code;
              IF this_font.hmetrics.exists(this_font.code2glyph(t_real)) THEN
                this_font.char_width_tab(t_code) := trunc(this_font.hmetrics(this_font.code2glyph(t_real)) * this_font.unit_norm);
              ELSE
                this_font.char_width_tab(t_code) := trunc(this_font.hmetrics(this_font.hmetrics.last()) * this_font.unit_norm);
              END IF;
            ELSE
              this_font.char_width_tab(t_code) := trunc(this_font.hmetrics(0) * this_font.unit_norm);
            END IF;
          END LOOP;
        END;
      ELSE
        DECLARE
          t_unicode         PLS_INTEGER;
          t_prv_diff        PLS_INTEGER;
          t_utf16_charset   VARCHAR2(1000);
          t_winansi_charset VARCHAR2(1000);
          t_glyphname       tp_glyphname;
        BEGIN
          t_prv_diff        := -1;
          t_utf16_charset   := substr(this_font.charset, 1, instr(this_font.charset, '.')) || 'AL16UTF16';
          t_winansi_charset := substr(this_font.charset, 1, instr(this_font.charset, '.')) || 'WE8MSWIN1252';
          FOR t_code IN 32 .. 255 LOOP
            t_unicode := utl_raw.cast_to_binary_integer(utl_raw.convert(hextoraw(to_char(t_code, 'fm0x')), t_utf16_charset, this_font.charset));
            t_glyphname := '';
            this_font.char_width_tab(t_code) := trunc(this_font.hmetrics(this_font.hmetrics.last()) * this_font.unit_norm);
            IF this_font.code2glyph.exists(t_unicode) THEN
              this_font.first_char := least(nvl(this_font.first_char, 255), t_code);
              this_font.last_char  := t_code;
              IF this_font.hmetrics.exists(this_font.code2glyph(t_unicode)) THEN
                this_font.char_width_tab(t_code) := trunc(this_font.hmetrics(this_font.code2glyph(t_unicode)) * this_font.unit_norm);
              END IF;
              IF t_glyph2name.exists(this_font.code2glyph(t_unicode)) THEN
                IF t_glyphnames.exists(t_glyph2name(this_font.code2glyph(t_unicode))) THEN
                  t_glyphname := t_glyphnames(t_glyph2name(this_font.code2glyph(t_unicode)));
                END IF;
              END IF;
            END IF;
            --
            IF (t_glyphname IS NOT NULL AND t_unicode != utl_raw.cast_to_binary_integer(utl_raw.convert(hextoraw(to_char(t_code, 'fm0x')), t_winansi_charset, this_font.charset))) THEN
              this_font.diff := this_font.diff || CASE
                                  WHEN t_prv_diff != t_code - 1 THEN
                                   ' ' || t_code
                                END || ' /' || t_glyphname;
              t_prv_diff     := t_code;
            END IF;
          END LOOP;
        END;
        IF this_font.diff IS NOT NULL THEN
          this_font.diff := '/Differences [' || this_font.diff || ']';
        END IF;
      END IF;
    END IF;
    --
    t_font_ind := g_fonts.count() + 1;
    g_fonts(t_font_ind) := this_font;
    /*
    --
    dbms_output.put_line( this_font.fontname || ' ' || this_font.family || ' ' || this_font.style
    || ' ' || this_font.flags
    || ' ' || this_font.code2glyph.first
    || ' ' || this_font.code2glyph.prior( this_font.code2glyph.last )
    || ' ' || this_font.code2glyph.last
    || ' nr glyphs: ' || this_font.numGlyphs
     ); */
    --
    RETURN t_font_ind;
  END;
  --
  PROCEDURE load_ttf_font(p_font     BLOB,
                          p_encoding VARCHAR2 := 'WINDOWS-1252',
                          p_embed    BOOLEAN := FALSE,
                          p_compress BOOLEAN := TRUE,
                          p_offset   NUMBER := 1) IS
    t_tmp PLS_INTEGER;
  BEGIN
    t_tmp := load_ttf_font(p_font, p_encoding, p_embed, p_compress);
  END;
  --
  FUNCTION load_ttf_font(p_dir      VARCHAR2 := 'MY_FONTS',
                         p_filename VARCHAR2 := 'BAUHS93.TTF',
                         p_encoding VARCHAR2 := 'WINDOWS-1252',
                         p_embed    BOOLEAN := FALSE,
                         p_compress BOOLEAN := TRUE) RETURN PLS_INTEGER IS
  BEGIN
    RETURN load_ttf_font(file2blob(p_dir, p_filename), p_encoding, p_embed, p_compress);
  END;
  --
  PROCEDURE load_ttf_font(p_dir      VARCHAR2 := 'MY_FONTS',
                          p_filename VARCHAR2 := 'BAUHS93.TTF',
                          p_encoding VARCHAR2 := 'WINDOWS-1252',
                          p_embed    BOOLEAN := FALSE,
                          p_compress BOOLEAN := TRUE) IS
  BEGIN
    load_ttf_font(file2blob(p_dir, p_filename), p_encoding, p_embed, p_compress);
  END;
  --
  PROCEDURE load_ttc_fonts(p_ttc      BLOB,
                           p_encoding VARCHAR2 := 'WINDOWS-1252',
                           p_embed    BOOLEAN := FALSE,
                           p_compress BOOLEAN := TRUE) IS
    TYPE tp_font_table IS RECORD(
      offset PLS_INTEGER,
      length PLS_INTEGER);
    TYPE tp_tables IS TABLE OF tp_font_table INDEX BY VARCHAR2(4);
    t_tables   tp_tables;
    t_tag      VARCHAR2(4);
    t_blob     BLOB;
    t_offset   PLS_INTEGER;
    t_font_ind PLS_INTEGER;
  BEGIN
    IF utl_raw.cast_to_varchar2(dbms_lob.substr(p_ttc, 4, 1)) != 'ttcf' THEN
      RETURN;
    END IF;
    FOR f IN 0 .. blob2num(p_ttc, 4, 9) - 1 LOOP
      t_font_ind := load_ttf_font(p_ttc, p_encoding, p_embed, p_compress, blob2num(p_ttc, 4, 13 + f * 4) + 1);
    END LOOP;
  END;
  --
  PROCEDURE load_ttc_fonts(p_dir      VARCHAR2 := 'MY_FONTS',
                           p_filename VARCHAR2 := 'CAMBRIA.TTC',
                           p_encoding VARCHAR2 := 'WINDOWS-1252',
                           p_embed    BOOLEAN := FALSE,
                           p_compress BOOLEAN := TRUE) IS
  BEGIN
    load_ttc_fonts(file2blob(p_dir, p_filename), p_encoding, p_embed, p_compress);
  END;
  --
  FUNCTION rgb(p_hex_rgb VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN to_char_round(nvl(to_number(substr(ltrim(p_hex_rgb, '#'), 1, 2), 'xx') / 255, 0), 5) || ' ' || to_char_round(nvl(to_number(substr(ltrim(p_hex_rgb, '#'), 3, 2), 'xx') / 255, 0), 5) || ' ' || to_char_round(nvl(to_number(substr(ltrim(p_hex_rgb, '#'), 5, 2), 'xx') / 255, 0), 5) || ' ';
  END;
  --
  PROCEDURE set_color(p_rgb    VARCHAR2 := '000000',
                      p_backgr BOOLEAN) IS
  BEGIN
    txt2page(rgb(p_rgb) || CASE WHEN p_backgr THEN 'RG' ELSE 'rg' END);
  END;
  --
  PROCEDURE set_color(p_rgb VARCHAR2 := '000000') IS
  BEGIN
    set_color(p_rgb, FALSE);
  END;
  --
  PROCEDURE set_color(p_red   NUMBER := 0,
                      p_green NUMBER := 0,
                      p_blue  NUMBER := 0) IS
  BEGIN
    IF (p_red BETWEEN 0 AND 255 AND p_blue BETWEEN 0 AND 255 AND p_green BETWEEN 0 AND 255) THEN
      set_color(to_char(p_red, 'fm0x') || to_char(p_green, 'fm0x') || to_char(p_blue, 'fm0x'), FALSE);
    END IF;
  END;
  --
  PROCEDURE set_bk_color(p_rgb VARCHAR2 := 'ffffff') IS
  BEGIN
    set_color(p_rgb, TRUE);
  END;
  --
  PROCEDURE set_bk_color(p_red   NUMBER := 0,
                         p_green NUMBER := 0,
                         p_blue  NUMBER := 0) IS
  BEGIN
    IF (p_red BETWEEN 0 AND 255 AND p_blue BETWEEN 0 AND 255 AND p_green BETWEEN 0 AND 255) THEN
      set_color(to_char(p_red, 'fm0x') || to_char(p_green, 'fm0x') || to_char(p_blue, 'fm0x'), TRUE);
    END IF;
  END;
  --
  PROCEDURE horizontal_line(p_x          NUMBER,
                            p_y          NUMBER,
                            p_width      NUMBER,
                            p_line_width NUMBER := 0.5,
                            p_line_color VARCHAR2 := '000000') IS
    t_use_color BOOLEAN;
  BEGIN
    txt2page('q ' || to_char_round(p_line_width, 5) || ' w');
    t_use_color := substr(p_line_color, -6) != '000000';
    IF t_use_color THEN
      set_color(p_line_color);
      set_bk_color(p_line_color);
    ELSE
      txt2page('0 g');
    END IF;
    txt2page(to_char_round(p_x, 5) || ' ' || to_char_round(p_y, 5) || ' m ' || to_char_round(p_x + p_width, 5) || ' ' || to_char_round(p_y, 5) || ' l b');
    txt2page('Q');
  END;
  --
  PROCEDURE vertical_line(p_x          NUMBER,
                          p_y          NUMBER,
                          p_height     NUMBER,
                          p_line_width NUMBER := 0.5,
                          p_line_color VARCHAR2 := '000000') IS
    t_use_color BOOLEAN;
  BEGIN
    txt2page('q ' || to_char_round(p_line_width, 5) || ' w');
    t_use_color := substr(p_line_color, -6) != '000000';
    IF t_use_color THEN
      set_color(p_line_color);
      set_bk_color(p_line_color);
    ELSE
      txt2page('0 g');
    END IF;
    txt2page(to_char_round(p_x, 5) || ' ' || to_char_round(p_y, 5) || ' m ' || to_char_round(p_x, 5) || ' ' || to_char_round(p_y + p_height, 5) || ' l b');
    txt2page('Q');
  END;
  --
  PROCEDURE rect(p_x          NUMBER,
                 p_y          NUMBER,
                 p_width      NUMBER,
                 p_height     NUMBER,
                 p_line_color VARCHAR2 := NULL,
                 p_fill_color VARCHAR2 := NULL,
                 p_line_width NUMBER := 0.5) IS
  BEGIN
    txt2page('q');
    IF substr(p_line_color, -6) != substr(p_fill_color, -6) THEN
      txt2page(to_char_round(p_line_width, 5) || ' w');
    END IF;
    IF substr(p_line_color, -6) != '000000' THEN
      set_bk_color(p_line_color);
    ELSE
      txt2page('0 g');
    END IF;
    IF p_fill_color IS NOT NULL THEN
      set_color(p_fill_color);
    END IF;
    txt2page(to_char_round(p_x, 5) || ' ' || to_char_round(p_y, 5) || ' ' || to_char_round(p_width, 5) || ' ' || to_char_round(p_height, 5) || ' re ' || CASE WHEN p_fill_color IS NULL THEN 'S' ELSE CASE WHEN p_line_color IS NULL THEN 'f' ELSE 'b' END END);
    txt2page('Q');
  END;
  --
  FUNCTION get(p_what PLS_INTEGER) RETURN NUMBER IS
  BEGIN
    RETURN CASE p_what WHEN c_get_page_width THEN g_settings.page_width WHEN c_get_page_height THEN g_settings.page_height WHEN c_get_margin_top THEN g_settings.margin_top WHEN c_get_margin_right THEN g_settings.margin_right WHEN c_get_margin_bottom THEN g_settings.margin_bottom WHEN c_get_margin_left THEN g_settings.margin_left WHEN c_get_x THEN g_x WHEN c_get_y THEN g_y WHEN c_get_fontsize THEN g_fonts(g_current_font).fontsize WHEN c_get_current_font THEN g_current_font END;
  END;
  --
  FUNCTION parse_jpg(p_img_blob BLOB) RETURN tp_img IS
    buf   RAW(4);
    t_img tp_img;
    t_ind INTEGER;
  BEGIN
    IF (dbms_lob.substr(p_img_blob, 2, 1) != hextoraw('FFD8') -- SOI Start of Image
       OR dbms_lob.substr(p_img_blob, 2, dbms_lob.getlength(p_img_blob) - 1) != hextoraw('FFD9') -- EOI End of Image
       ) THEN
      -- this is not a jpg I can handle
      RETURN NULL;
    END IF;
    --
    t_img.pixels := p_img_blob;
    t_img.type   := 'jpg';
    IF dbms_lob.substr(t_img.pixels, 2, 3) IN (hextoraw('FFE0') -- a APP0 jpg
                                              , hextoraw('FFE1') -- a APP1 jpg
                                               ) THEN
      t_img.color_res := 8;
      t_img.height    := 1;
      t_img.width     := 1;
      --
      t_ind := 3;
      t_ind := t_ind + 2 + blob2num(t_img.pixels, 2, t_ind + 2);
      LOOP
        buf := dbms_lob.substr(t_img.pixels, 2, t_ind);
        EXIT WHEN buf = hextoraw('FFDA'); -- SOS Start of Scan
        EXIT WHEN buf = hextoraw('FFD9'); -- EOI End Of Image
        EXIT WHEN substr(rawtohex(buf), 1, 2) != 'FF';
        IF rawtohex(buf) IN ('FFD0' -- RSTn
                            , 'FFD1', 'FFD2', 'FFD3', 'FFD4', 'FFD5', 'FFD6', 'FFD7', 'FF01' -- TEM
                             ) THEN
          t_ind := t_ind + 2;
        ELSE
          IF buf = hextoraw('FFC0') -- SOF0 (Start Of Frame 0) marker
           THEN
            t_img.color_res := blob2num(t_img.pixels, 1, t_ind + 4);
            t_img.height    := blob2num(t_img.pixels, 2, t_ind + 5);
            t_img.width     := blob2num(t_img.pixels, 2, t_ind + 7);
          END IF;
          t_ind := t_ind + 2 + blob2num(t_img.pixels, 2, t_ind + 2);
        END IF;
      END LOOP;
    END IF;
    --
    RETURN t_img;
  END;
  --
  FUNCTION parse_png(p_img_blob BLOB) RETURN tp_img IS
    t_img      tp_img;
    buf        RAW(32767);
    len        INTEGER;
    ind        INTEGER;
    color_type PLS_INTEGER;
  BEGIN
    IF rawtohex(dbms_lob.substr(p_img_blob, 8, 1)) != '89504E470D0A1A0A' -- not the right signature
     THEN
      RETURN NULL;
    END IF;
    dbms_lob.createtemporary(t_img.pixels, TRUE);
    ind := 9;
    LOOP
      len := blob2num(p_img_blob, 4, ind); -- length
      EXIT WHEN len IS NULL OR ind > dbms_lob.getlength(p_img_blob);
      CASE utl_raw.cast_to_varchar2(dbms_lob.substr(p_img_blob, 4, ind + 4)) -- Chunk type
        WHEN 'IHDR' THEN
          t_img.width     := blob2num(p_img_blob, 4, ind + 8);
          t_img.height    := blob2num(p_img_blob, 4, ind + 12);
          t_img.color_res := blob2num(p_img_blob, 1, ind + 16);
          color_type      := blob2num(p_img_blob, 1, ind + 17);
          t_img.greyscale := color_type IN (0, 4);
        WHEN 'PLTE' THEN
          t_img.color_tab := dbms_lob.substr(p_img_blob, len, ind + 8);
        WHEN 'IDAT' THEN
          dbms_lob.copy(t_img.pixels, p_img_blob, len, dbms_lob.getlength(t_img.pixels) + 1, ind + 8);
        WHEN 'IEND' THEN
          EXIT;
        ELSE
          NULL;
      END CASE;
      ind := ind + 4 + 4 + len + 4; -- Length + Chunk type + Chunk data + CRC
    END LOOP;
    --
    t_img.type      := 'png';
    t_img.nr_colors := CASE color_type
                         WHEN 0 THEN
                          1
                         WHEN 2 THEN
                          3
                         WHEN 3 THEN
                          1
                         WHEN 4 THEN
                          2
                         ELSE
                          4
                       END;
    --
    RETURN t_img;
  END;
  --
  FUNCTION lzw_decompress(p_blob BLOB,
                          p_bits PLS_INTEGER) RETURN BLOB IS
    powers tp_pls_tab;
    --
    g_lzw_ind       PLS_INTEGER;
    g_lzw_bits      PLS_INTEGER;
    g_lzw_buffer    PLS_INTEGER;
    g_lzw_bits_used PLS_INTEGER;
    --
    TYPE tp_lzw_dict IS TABLE OF RAW(1000) INDEX BY PLS_INTEGER;
    t_lzw_dict tp_lzw_dict;
    t_clr_code PLS_INTEGER;
    t_nxt_code PLS_INTEGER;
    t_new_code PLS_INTEGER;
    t_old_code PLS_INTEGER;
    t_blob     BLOB;
    --
    FUNCTION get_lzw_code RETURN PLS_INTEGER IS
      t_rv PLS_INTEGER;
    BEGIN
      WHILE g_lzw_bits_used < g_lzw_bits LOOP
        g_lzw_ind       := g_lzw_ind + 1;
        g_lzw_buffer    := blob2num(p_blob, 1, g_lzw_ind) * powers(g_lzw_bits_used) + g_lzw_buffer;
        g_lzw_bits_used := g_lzw_bits_used + 8;
      END LOOP;
      t_rv            := bitand(g_lzw_buffer, powers(g_lzw_bits) - 1);
      g_lzw_bits_used := g_lzw_bits_used - g_lzw_bits;
      g_lzw_buffer    := trunc(g_lzw_buffer / powers(g_lzw_bits));
      RETURN t_rv;
    END;
    --
  BEGIN
    FOR i IN 0 .. 30 LOOP
      powers(i) := power(2, i);
    END LOOP;
    --
    t_clr_code := powers(p_bits - 1);
    t_nxt_code := t_clr_code + 2;
    FOR i IN 0 .. least(t_clr_code - 1, 255) LOOP
      t_lzw_dict(i) := hextoraw(to_char(i, 'fm0X'));
    END LOOP;
    dbms_lob.createtemporary(t_blob, TRUE);
    g_lzw_ind       := 0;
    g_lzw_bits      := p_bits;
    g_lzw_buffer    := 0;
    g_lzw_bits_used := 0;
    --
    t_old_code := NULL;
    t_new_code := get_lzw_code();
    LOOP
      CASE nvl(t_new_code, t_clr_code + 1)
        WHEN t_clr_code + 1 THEN
          EXIT;
        WHEN t_clr_code THEN
          t_new_code := NULL;
          g_lzw_bits := p_bits;
          t_nxt_code := t_clr_code + 2;
        ELSE
          IF t_new_code = t_nxt_code THEN
            t_lzw_dict(t_nxt_code) := utl_raw.concat(t_lzw_dict(t_old_code), utl_raw.substr(t_lzw_dict(t_old_code), 1, 1));
            dbms_lob.append(t_blob, t_lzw_dict(t_nxt_code));
            t_nxt_code := t_nxt_code + 1;
          ELSIF t_new_code > t_nxt_code THEN
            EXIT;
          ELSE
            dbms_lob.append(t_blob, t_lzw_dict(t_new_code));
            IF t_old_code IS NOT NULL THEN
              t_lzw_dict(t_nxt_code) := utl_raw.concat(t_lzw_dict(t_old_code), utl_raw.substr(t_lzw_dict(t_new_code), 1, 1));
              t_nxt_code := t_nxt_code + 1;
            END IF;
          END IF;
          IF bitand(t_nxt_code, powers(g_lzw_bits) - 1) = 0
             AND g_lzw_bits < 12 THEN
            g_lzw_bits := g_lzw_bits + 1;
          END IF;
      END CASE;
      t_old_code := t_new_code;
      t_new_code := get_lzw_code();
    END LOOP;
    t_lzw_dict.delete;
    --
    RETURN t_blob;
  END;
  --
  FUNCTION parse_gif(p_img_blob BLOB) RETURN tp_img IS
    img   tp_img;
    buf   RAW(4000);
    ind   INTEGER;
    t_len PLS_INTEGER;
  BEGIN
    IF dbms_lob.substr(p_img_blob, 3, 1) != utl_raw.cast_to_raw('GIF') THEN
      RETURN NULL;
    END IF;
    ind           := 7;
    buf           := dbms_lob.substr(p_img_blob, 7, 7); --  Logical Screen Descriptor
    ind           := ind + 7;
    img.color_res := raw2num(utl_raw.bit_and(utl_raw.substr(buf, 5, 1), hextoraw('70'))) / 16 + 1;
    img.color_res := 8;
    IF raw2num(buf, 5, 1) > 127 THEN
      t_len         := 3 * power(2, raw2num(utl_raw.bit_and(utl_raw.substr(buf, 5, 1), hextoraw('07'))) + 1);
      img.color_tab := dbms_lob.substr(p_img_blob, t_len, ind); -- Global Color Table
      ind           := ind + t_len;
    END IF;
    --
    LOOP
      CASE dbms_lob.substr(p_img_blob, 1, ind)
        WHEN hextoraw('3B') -- trailer
         THEN
          EXIT;
        WHEN hextoraw('21') -- extension
         THEN
          IF dbms_lob.substr(p_img_blob, 1, ind + 1) = hextoraw('F9') THEN
            -- Graphic Control Extension
            IF utl_raw.bit_and(dbms_lob.substr(p_img_blob, 1, ind + 3), hextoraw('01')) = hextoraw('01') THEN
              -- Transparent Color Flag set
              img.transparancy_index := blob2num(p_img_blob, 1, ind + 6);
            END IF;
          END IF;
          ind := ind + 2; -- skip sentinel + label
          LOOP
            t_len := blob2num(p_img_blob, 1, ind); -- Block Size
            EXIT WHEN t_len = 0;
            ind := ind + 1 + t_len; -- skip Block Size + Data Sub-block
          END LOOP;
          ind := ind + 1; -- skip last Block Size
        WHEN hextoraw('2C') -- image
         THEN
          DECLARE
            img_blob      BLOB;
            min_code_size PLS_INTEGER;
            code_size     PLS_INTEGER;
            flags         RAW(1);
          BEGIN
            img.width     := utl_raw.cast_to_binary_integer(dbms_lob.substr(p_img_blob, 2, ind + 5), utl_raw.little_endian);
            img.height    := utl_raw.cast_to_binary_integer(dbms_lob.substr(p_img_blob, 2, ind + 7), utl_raw.little_endian);
            img.greyscale := FALSE;
            ind           := ind + 1 + 8; -- skip sentinel + img sizes
            flags         := dbms_lob.substr(p_img_blob, 1, ind);
            IF utl_raw.bit_and(flags, hextoraw('80')) = hextoraw('80') THEN
              t_len         := 3 * power(2, raw2num(utl_raw.bit_and(flags, hextoraw('07'))) + 1);
              img.color_tab := dbms_lob.substr(p_img_blob, t_len, ind + 1); -- Local Color Table
            END IF;
            ind           := ind + 1; -- skip image Flags
            min_code_size := blob2num(p_img_blob, 1, ind);
            ind           := ind + 1; -- skip LZW Minimum Code Size
            dbms_lob.createtemporary(img_blob, TRUE);
            LOOP
              t_len := blob2num(p_img_blob, 1, ind); -- Block Size
              EXIT WHEN t_len = 0;
              dbms_lob.append(img_blob, dbms_lob.substr(p_img_blob, t_len, ind + 1)); -- Data Sub-block
              ind := ind + 1 + t_len; -- skip Block Size + Data Sub-block
            END LOOP;
            ind        := ind + 1; -- skip last Block Size
            img.pixels := lzw_decompress(img_blob, min_code_size + 1);
            --
            IF utl_raw.bit_and(flags, hextoraw('40')) = hextoraw('40') THEN
              --  interlaced
              DECLARE
                pass     PLS_INTEGER;
                pass_ind tp_pls_tab;
              BEGIN
                dbms_lob.createtemporary(img_blob, TRUE);
                pass_ind(1) := 1;
                pass_ind(2) := trunc((img.height - 1) / 8) + 1;
                pass_ind(3) := pass_ind(2) + trunc((img.height + 3) / 8);
                pass_ind(4) := pass_ind(3) + trunc((img.height + 1) / 4);
                pass_ind(2) := pass_ind(2) * img.width + 1;
                pass_ind(3) := pass_ind(3) * img.width + 1;
                pass_ind(4) := pass_ind(4) * img.width + 1;
                FOR i IN 0 .. img.height - 1 LOOP
                  pass := CASE MOD(i, 8)
                            WHEN 0 THEN
                             1
                            WHEN 4 THEN
                             2
                            WHEN 2 THEN
                             3
                            WHEN 6 THEN
                             3
                            ELSE
                             4
                          END;
                  dbms_lob.append(img_blob, dbms_lob.substr(img.pixels, img.width, pass_ind(pass)));
                  pass_ind(pass) := pass_ind(pass) + img.width;
                END LOOP;
                img.pixels := img_blob;
              END;
            END IF;
            --
            dbms_lob.freetemporary(img_blob);
          END;
        ELSE
          EXIT;
      END CASE;
    END LOOP;
    --
    img.type := 'gif';
    RETURN img;
  END;
  --
  FUNCTION parse_img(p_blob    IN BLOB,
                     p_adler32 IN VARCHAR2 := NULL,
                     p_type    IN VARCHAR2 := NULL) RETURN tp_img IS
    t_img tp_img;
  BEGIN
    t_img.type := p_type;
    IF t_img.type IS NULL THEN
      IF rawtohex(dbms_lob.substr(p_blob, 8, 1)) = '89504E470D0A1A0A' THEN
        t_img.type := 'png';
      ELSIF dbms_lob.substr(p_blob, 3, 1) = utl_raw.cast_to_raw('GIF') THEN
        t_img.type := 'gif';
      ELSE
        t_img.type := 'jpg';
      END IF;
    END IF;
    --
    t_img := CASE lower(t_img.type)
               WHEN 'gif' THEN
                parse_gif(p_blob)
               WHEN 'png' THEN
                parse_png(p_blob)
               WHEN 'jpg' THEN
                parse_jpg(p_blob)
               ELSE
                NULL
             END;
    --
    IF t_img.type IS NOT NULL THEN
      t_img.adler32 := coalesce(p_adler32, adler32(p_blob));
    END IF;
    RETURN t_img;
  END;
  --
  PROCEDURE put_image(p_img     BLOB,
                      p_x       NUMBER,
                      p_y       NUMBER,
                      p_width   NUMBER := NULL,
                      p_height  NUMBER := NULL,
                      p_align   VARCHAR2 := 'center',
                      p_valign  VARCHAR2 := 'top',
                      p_adler32 VARCHAR2 := NULL) IS
    t_x       NUMBER;
    t_y       NUMBER;
    t_img     tp_img;
    t_ind     PLS_INTEGER;
    t_adler32 VARCHAR2(8) := p_adler32;
  BEGIN
    IF p_img IS NULL THEN
      RETURN;
    END IF;
    IF t_adler32 IS NULL THEN
      t_adler32 := adler32(p_img);
    END IF;
    t_ind := g_images.first;
    WHILE t_ind IS NOT NULL LOOP
      EXIT WHEN g_images(t_ind).adler32 = t_adler32;
      t_ind := g_images.next(t_ind);
    END LOOP;
    --
    IF t_ind IS NULL THEN
      t_img := parse_img(p_img, t_adler32);
      IF t_img.adler32 IS NULL THEN
        RETURN;
      END IF;
      t_ind := g_images.count() + 1;
      g_images(t_ind) := t_img;
    END IF;
    --
    t_x := CASE substr(upper(p_align), 1, 1)
             WHEN 'L' THEN
              p_x -- left
             WHEN 'S' THEN
              p_x -- start
             WHEN 'R' THEN
              p_x + nvl(p_width, 0) - g_images(t_ind).width -- right
             WHEN 'E' THEN
              p_x + nvl(p_width, 0) - g_images(t_ind).width -- end
             ELSE
              (p_x + nvl(p_width, 0) - g_images(t_ind).width) / 2 -- center
           END;
    t_y := CASE substr(upper(p_valign), 1, 1)
             WHEN 'C' THEN
              (p_y - nvl(p_height, 0) + g_images(t_ind).height) / 2 -- center
             WHEN 'B' THEN
              p_y - nvl(p_height, 0) + g_images(t_ind).height -- bottom
             ELSE
              p_y -- top
           END;
    --
    txt2page('q ' || to_char_round(least(nvl(p_width, g_images(t_ind).width), g_images(t_ind).width)) || ' 0 0 ' || to_char_round(least(nvl(p_height, g_images(t_ind).height), g_images(t_ind).height)) || ' ' || to_char_round(t_x) || ' ' || to_char_round(t_y) || ' cm /I' || to_char(t_ind) || ' Do Q');
  END;
  --
  PROCEDURE put_image(p_dir       VARCHAR2,
                      p_file_name VARCHAR2,
                      p_x         NUMBER,
                      p_y         NUMBER,
                      p_width     NUMBER := NULL,
                      p_height    NUMBER := NULL,
                      p_align     VARCHAR2 := 'center',
                      p_valign    VARCHAR2 := 'top',
                      p_adler32   VARCHAR2 := NULL) IS
    t_blob BLOB;
  BEGIN
    t_blob := file2blob(p_dir, p_file_name);
    put_image(t_blob, p_x, p_y, p_width, p_height, p_align, p_valign, p_adler32);
    dbms_lob.freetemporary(t_blob);
  END;
  --
  PROCEDURE put_image(p_url     VARCHAR2,
                      p_x       NUMBER,
                      p_y       NUMBER,
                      p_width   NUMBER := NULL,
                      p_height  NUMBER := NULL,
                      p_align   VARCHAR2 := 'center',
                      p_valign  VARCHAR2 := 'top',
                      p_adler32 VARCHAR2 := NULL) IS
    t_blob BLOB;
  BEGIN
    t_blob := httpuritype(p_url).getblob();
    put_image(t_blob, p_x, p_y, p_width, p_height, p_align, p_valign, p_adler32);
    dbms_lob.freetemporary(t_blob);
  END;
  --
  PROCEDURE set_page_proc(p_src CLOB) IS
  BEGIN
    g_page_prcs(g_page_prcs.count) := p_src;
  END;
  --
  PROCEDURE cursor2table(p_c       INTEGER,
                         p_widths  tp_col_widths := NULL,
                         p_headers tp_headers := NULL) IS
    t_col_cnt INTEGER;
    $IF DBMS_DB_VERSION.VER_LE_10 $THEN
    t_desc_tab dbms_sql.desc_tab2;
    $ELSE
    t_desc_tab dbms_sql.desc_tab3;
    $END
    d_tab       dbms_sql.date_table;
    n_tab       dbms_sql.number_table;
    v_tab       dbms_sql.varchar2_table;
    t_bulk_size PLS_INTEGER := 200;
    t_r         INTEGER;
    t_cur_row   PLS_INTEGER;
    TYPE tp_integer_tab IS TABLE OF INTEGER;
    t_chars       tp_integer_tab := tp_integer_tab(1, 8, 9, 96, 112);
    t_dates       tp_integer_tab := tp_integer_tab(12, 178, 179, 180, 181, 231);
    t_numerics    tp_integer_tab := tp_integer_tab(2, 100, 101);
    t_widths      tp_col_widths;
    t_tmp         NUMBER;
    t_x           NUMBER;
    t_y           NUMBER;
    t_start_x     NUMBER;
    t_lineheight  NUMBER;
    t_padding     NUMBER := 2;
    t_num_format  VARCHAR2(100) := 'tm9';
    t_date_format VARCHAR2(100) := 'dd.mm.yyyy';
    t_txt         VARCHAR2(32767);
    c_rf          NUMBER := 0.2; -- raise factor of text above cell bottom
    --
    PROCEDURE show_header IS
    BEGIN
      IF p_headers IS NOT NULL
         AND p_headers.count > 0 THEN
        t_x := t_start_x;
        FOR c IN 1 .. t_col_cnt LOOP
          rect(t_x, t_y, t_widths(c), t_lineheight);
          IF c <= p_headers.count THEN
            put_txt(t_x + t_padding, t_y + c_rf * t_lineheight, p_headers(c));
          END IF;
          t_x := t_x + t_widths(c);
        END LOOP;
        t_y := t_y - t_lineheight;
      END IF;
    END;
    --
  BEGIN
    $IF DBMS_DB_VERSION.VER_LE_10 $THEN
    dbms_sql.describe_columns2(p_c, t_col_cnt, t_desc_tab);
    $ELSE
    dbms_sql.describe_columns3(p_c, t_col_cnt, t_desc_tab);
    $END
    IF p_widths IS NULL
       OR p_widths.count < t_col_cnt THEN
      t_tmp    := get(c_get_page_width) - get(c_get_margin_left) - get(c_get_margin_right);
      t_widths := tp_col_widths();
      t_widths.extend(t_col_cnt);
      FOR c IN 1 .. t_col_cnt LOOP
        t_widths(c) := round(t_tmp / t_col_cnt, 1);
      END LOOP;
    ELSE
      t_widths := p_widths;
    END IF;
    --
    IF get(c_get_current_font) IS NULL THEN
      set_font('helvetica', 12);
    END IF;
    --
    FOR c IN 1 .. t_col_cnt LOOP
      CASE
        WHEN t_desc_tab(c).col_type MEMBER OF t_numerics THEN
          dbms_sql.define_array(p_c, c, n_tab, t_bulk_size, 1);
        WHEN t_desc_tab(c).col_type MEMBER OF t_dates THEN
          dbms_sql.define_array(p_c, c, d_tab, t_bulk_size, 1);
        WHEN t_desc_tab(c).col_type MEMBER OF t_chars THEN
          dbms_sql.define_array(p_c, c, v_tab, t_bulk_size, 1);
        ELSE
          NULL;
      END CASE;
    END LOOP;
    --
    t_start_x    := get(c_get_margin_left);
    t_lineheight := get(c_get_fontsize) * 1.2;
    t_y          := coalesce(get(c_get_y) - t_lineheight, get(c_get_page_height) - get(c_get_margin_top)) - t_lineheight;
    --
    show_header;
    --
    LOOP
      t_r := dbms_sql.fetch_rows(p_c);
      FOR i IN 0 .. t_r - 1 LOOP
        IF t_y < get(c_get_margin_bottom) THEN
          new_page;
          t_y := get(c_get_page_height) - get(c_get_margin_top) - t_lineheight;
          show_header;
        END IF;
        t_x := t_start_x;
        FOR c IN 1 .. t_col_cnt LOOP
          CASE
            WHEN t_desc_tab(c).col_type MEMBER OF t_numerics THEN
              n_tab.delete;
              dbms_sql.column_value(p_c, c, n_tab);
              rect(t_x, t_y, t_widths(c), t_lineheight);
              t_txt := to_char(n_tab(i + n_tab.first()), t_num_format);
              IF t_txt IS NOT NULL THEN
                put_txt(t_x + t_widths(c) - t_padding - str_len(t_txt), t_y + c_rf * t_lineheight, t_txt);
              END IF;
              t_x := t_x + t_widths(c);
            WHEN t_desc_tab(c).col_type MEMBER OF t_dates THEN
              d_tab.delete;
              dbms_sql.column_value(p_c, c, d_tab);
              rect(t_x, t_y, t_widths(c), t_lineheight);
              t_txt := to_char(d_tab(i + d_tab.first()), t_date_format);
              IF t_txt IS NOT NULL THEN
                put_txt(t_x + t_padding, t_y + c_rf * t_lineheight, t_txt);
              END IF;
              t_x := t_x + t_widths(c);
            WHEN t_desc_tab(c).col_type MEMBER OF t_chars THEN
              v_tab.delete;
              dbms_sql.column_value(p_c, c, v_tab);
              rect(t_x, t_y, t_widths(c), t_lineheight);
              t_txt := v_tab(i + v_tab.first());
              IF t_txt IS NOT NULL THEN
                put_txt(t_x + t_padding, t_y + c_rf * t_lineheight, t_txt);
              END IF;
              t_x := t_x + t_widths(c);
            ELSE
              NULL;
          END CASE;
        END LOOP;
        t_y := t_y - t_lineheight;
      END LOOP;
      EXIT WHEN t_r != t_bulk_size;
    END LOOP;
    g_y := t_y;
  END;
  --
  PROCEDURE query2table(p_query   VARCHAR2,
                        p_widths  tp_col_widths := NULL,
                        p_headers tp_headers := NULL) IS
    t_cx    INTEGER;
    t_dummy INTEGER;
  BEGIN
    t_cx := dbms_sql.open_cursor;
    dbms_sql.parse(t_cx, p_query, dbms_sql.native);
    t_dummy := dbms_sql.execute(t_cx);
    cursor2table(t_cx, p_widths, p_headers);
    dbms_sql.close_cursor(t_cx);
  END;

  PROCEDURE PR_GOTO_PAGE(i_nPage IN NUMBER) IS
  BEGIN
    IF i_nPage <= g_pages.count THEN
      g_page_nr := i_nPage - 1;
    END IF;
  END;

  PROCEDURE PR_GOTO_CURRENT_PAGE IS
  BEGIN
    g_page_nr := NULL;
  END;

  FUNCTION FK_GET_PAGE RETURN NUMBER IS
  BEGIN
    RETURN g_page_nr;
  END;

  PROCEDURE PR_LINE(i_nX1         IN NUMBER,
                    i_nY1         IN NUMBER,
                    i_nX2         IN NUMBER,
                    i_nY2         IN NUMBER,
                    i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                    i_nLineWidth  IN NUMBER DEFAULT 0.5,
                    i_vcStroke    IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    txt2page('q ');
    txt2page(to_char_round(i_nLineWidth, 5) || ' w');
    IF SUBSTR(i_vcLineColor, -6) != '000000' THEN
      set_bk_color(i_vcLineColor);
    ELSE
      txt2page('0 g');
    END IF;
  
    txt2page('n ');
    IF i_vcStroke IS NOT NULL THEN
      txt2page(i_vcStroke || ' d ');
    END IF;
    txt2page(to_char_round(i_nX1, 5) || ' ' || to_char_round(i_nY1, 5) || ' m ');
    txt2page(to_char_round(i_nX2, 5) || ' ' || to_char_round(i_nY2, 5) || ' l S Q');
  END;

  PROCEDURE PR_POLYGON(i_lXs         IN tVertices,
                       i_lYs         IN tVertices,
                       i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                       i_vcFillColor IN VARCHAR2 DEFAULT NULL,
                       i_nLineWidth  IN NUMBER DEFAULT 0.5) IS
    vcBuffer VARCHAR2(32767);
  BEGIN
    IF i_lXs.COUNT > 0
       AND i_lXs.COUNT = i_lYs.COUNT THEN
      txt2page('q ');
      IF SUBSTR(i_vcLineColor, -6) != SUBSTR(i_vcFillColor, -6) THEN
        txt2page(to_char_round(i_nLineWidth, 5) || ' w');
      END IF;
      IF SUBSTR(i_vcLineColor, -6) != '000000' THEN
        set_bk_color(i_vcLineColor);
      ELSE
        txt2page('0 g');
      END IF;
      IF i_vcFillColor IS NOT NULL THEN
        set_color(i_vcFillColor);
      END IF;
      txt2page(' 2.00000 M ');
      txt2page('n ');
    
      vcBuffer := to_char_round(i_lXs(1), 5) || ' ' || to_char_round(i_lYs(1), 5) || ' m ';
      FOR i IN 2 .. i_lXs.COUNT LOOP
        vcBuffer := vcBuffer || to_char_round(i_lXs(i), 5) || ' ' || to_char_round(i_lYs(i), 5) || ' l ';
      END LOOP;
      vcBuffer := vcBuffer || to_char_round(i_lXs(1), 5) || ' ' || to_char_round(i_lYs(1), 5) || ' l ';
      vcBuffer := vcBuffer || CASE
                    WHEN i_vcFillColor IS NULL THEN
                     'S'
                    ELSE
                     CASE
                       WHEN i_vcLineColor IS NULL THEN
                        'f'
                       ELSE
                        'b'
                     END
                  END;
    
      txt2page(vcBuffer || ' Q');
    END IF;
  END;

  PROCEDURE PR_PATH(i_lPath       IN tPath,
                    i_vcLineColor IN VARCHAR2 DEFAULT NULL,
                    i_vcFillColor IN VARCHAR2 DEFAULT NULL,
                    i_nLineWidth  IN NUMBER DEFAULT 0.5) IS
    vcBuffer VARCHAR2(32767);
  BEGIN
    txt2page('q ');
  
    IF SUBSTR(i_vcLineColor, -6) != SUBSTR(i_vcFillColor, -6) THEN
      txt2page(to_char_round(i_nLineWidth, 5) || ' w');
    END IF;
    IF SUBSTR(i_vcLineColor, -6) != '000000' THEN
      set_bk_color(i_vcLineColor);
    ELSE
      txt2page('0 g');
    END IF;
    IF i_vcFillColor IS NOT NULL THEN
      set_color(i_vcFillColor);
    END IF;
  
    txt2page('n ');
    FOR i IN 1 .. i_lPath.COUNT LOOP
      IF i_lPath(i).nType = PATH_MOVE_TO THEN
        vcBuffer := vcBuffer || to_char_round(i_lPath(i).nVal1, 5) || ' ' || to_char_round(i_lPath(i).nVal2, 5) || ' m ';
      ELSIF i_lPath(i).nType = PATH_LINE_TO THEN
        vcBuffer := vcBuffer || to_char_round(i_lPath(i).nVal1, 5) || ' ' || to_char_round(i_lPath(i).nVal2, 5) || ' l ';
      ELSIF i_lPath(i).nType = PATH_CURVE_TO THEN
        vcBuffer := vcBuffer || to_char_round(i_lPath(i).nVal1, 5) || ' ' || to_char_round(i_lPath(i).nVal2, 5) || ' ' || to_char_round(i_lPath(i).nVal3, 5) || ' ' || to_char_round(i_lPath(i).nVal4, 5) || ' ' || to_char_round(i_lPath(i).nVal5, 5) || ' ' || to_char_round(i_lPath(i).nVal6, 5) ||
                    ' c ';
      ELSIF i_lPath(i).nType = PATH_CLOSE THEN
        vcBuffer := vcBuffer || CASE
                      WHEN i_vcFillColor IS NULL THEN
                       'S'
                      ELSE
                       CASE
                         WHEN i_vcLineColor IS NULL THEN
                          'f'
                         ELSE
                          'b'
                       END
                    END;
      END IF;
    END LOOP;
  
    txt2page(vcBuffer || ' Q');
  END;

  $IF not DBMS_DB_VERSION.VER_LE_10 $THEN
  --
  PROCEDURE refcursor2table(p_rc      SYS_REFCURSOR,
                            p_widths  tp_col_widths := NULL,
                            p_headers tp_headers := NULL) IS
    t_cx INTEGER;
    t_rc SYS_REFCURSOR;
  BEGIN
    t_rc := p_rc;
    t_cx := dbms_sql.to_cursor_number(t_rc);
    cursor2table(t_cx, p_widths, p_headers);
    dbms_sql.close_cursor(t_cx);
  END;
  $END

BEGIN
  FOR i IN 0 .. 255 LOOP
    lHex(TO_CHAR(i, 'FM0X')) := i;
  END LOOP;
END;
/

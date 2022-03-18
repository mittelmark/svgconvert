/* -*- C -*- ****************************************************************
 *  Copyright (c) 2021 Detlef Groth.
 *  Based on code of Seth Moekel
 *  https://github.com/cosmotek/libsvgconv/blob/master/svgconv.c
 *
 ****************************************************************************/
#ifdef __cplusplus
extern "C"
#endif

#include <cairo.h>
#include <cairo/cairo-pdf.h>
#include <cairo/cairo-svg.h>
#include <librsvg/rsvg.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

void svgconvert(const char svgfile[], const char outfile[], double scalex, double scaley);

void svgconvert(const char svgfile[], const char outfile[], double scalex, double scaley) {
    char *epdf = ".pdf";
    char *esvg = ".svg";
    char *pdf = strstr(outfile, epdf);
    char *svg = strstr(outfile, esvg);    

    RsvgHandle *handle;
    RsvgDimensionData dimension_data;
    
    GError* err = NULL;
    handle = rsvg_handle_new_from_file(svgfile, &err);
    
    if (err != NULL) {
        fprintf(stderr, "libsvgconv: Failed to load svg: '%s'; %s\n", svgfile, (char*) err->message);
        g_error_free(err);
        err = NULL;
    }
    
    cairo_surface_t *surface;
    cairo_t *ctx;
    
    rsvg_handle_get_dimensions(handle, &dimension_data);
    double resx = ((double) dimension_data.width) * scalex;
    double resy = ((double) dimension_data.height) * scaley;
    if (pdf) {
        surface = cairo_pdf_surface_create(outfile, (int) resx, (int) resy); 
    } else if (svg) {
        surface = cairo_svg_surface_create(outfile, (int) resx, (int) resy); 
    } else {
        surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int) resx, (int) resy);
    }
    ctx = cairo_create(surface);
    
    cairo_set_source_rgba(ctx, 255, 255, 255, 0);
    cairo_scale(ctx, scalex, scaley);
    
    rsvg_handle_render_cairo(handle, ctx);
    cairo_paint(ctx);
    cairo_show_page(ctx);
    cairo_destroy(ctx);
    // Destroying cairo context
    cairo_surface_flush(surface);
    if (pdf || svg) {
        // Destroying PDF surface
        cairo_surface_destroy(surface);
    } else {
        cairo_surface_write_to_png(surface, outfile);
        cairo_surface_destroy(surface);
    } 
}

#ifdef MAINAPP 

int main(int argc, char* argv[]) {
    double scalex = 1.0;
    double scaley = 1.0;
    if (argc < 3) {
        printf("Usage: svgconv [svgfile] [outfile] ?[scalex] [scaley]?\n");
        
    } else {
        if (argc > 4) {
            sscanf(argv[3], "%lf", &scalex);
            sscanf(argv[4], "%lf", &scaley);
        }  else if (argc == 4) {
            sscanf(argv[3], "%lf", &scalex);
            scaley=scalex;
        }
        if( access( argv[1], F_OK ) == 0 ) {
            // printf("File %s does exists!\n",argv[1]);
        } else {
            printf("Error: File %s does not exists!\n",argv[1]);
            return(1);
        }
        svgconvert(argv[1],argv[2],scalex,scaley);
    }
    return(0);
}

#endif

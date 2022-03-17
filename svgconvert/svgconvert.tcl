
package require critcl
package provide svgconvert 1.0

if {![critcl::compiling]} {
    puts stderr "This extension cannot be compiled without critcl enabled"
    exit 1
}
namespace eval ::svgconvert {
    # collect all the include directories
    set options [regsub -all -- -I [exec pkg-config --cflags --libs cairo --libs librsvg-2.0] "I "]
    set dirs [list]
    foreach {i dir} $options {
        if {$i eq "I"} {
            lappend dirs $dir
        }
    }
    critcl::clibraries -lrsvg-2 -lm -lgio-2.0 -lgdk_pixbuf-2.0 -lgobject-2.0 -lglib-2.0 -lcairo -pthread
    critcl::config I $dirs
    critcl::ccode {
        #include <string.h>
        #include <stdio.h>
        #include <cairo.h>
        #include <cairo/cairo-pdf.h>
        #include <cairo/cairo-svg.h>        
        #include <librsvg/rsvg.h>
    }
    
    
    critcl::cproc svgconvert {char* svgfile  char* outfile double scalex double scaley} void {
        // new
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
    proc svgconv {infile outfile {scalex 1.0} {scaley 1.0}} {
        if {$scalex != $scaley} {
            set scaley $scalex
        }
        if {![file exists $infile]} {
            error "Error: File $infile does not exist!"
        }
        svgconvert::svgconvert $infile $outfile $scalex $scaley
    }
        
    proc svg2svg {svginfile svgoutfile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $svgoutfile] ne ".svg"} {
            error "Error: File extension for $svgoutfile is not .svg!"
        }
        svgconv $svginfile $svgoutfile $scalex $scaley
    }
    proc svg2pdf {svgfile pdffile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $pdffile] ne ".pdf"} {
            error "Error: File extension for $pdffile is not .pdf!"
        }
        svgconv $svgfile $pdffile $scalex $scaley
    }
    proc svg2png {svgfile pngfile {scalex 1.0} {scaley 1.0}} {
        if {[file extension $pngfile] ne ".png"} {
            error "Error: File extension for $pngfile is not .png!"
        }
        svgconv $svgfile $pngfile $scalex $scaley
    }
    namespace export svg2pdf svg2png svg2svg
}

if {$argv0 eq [info script]} {
    namespace import svgconvert::*
    svg2svg basic-shapes.svg basic-shapes-out.svg 0.5
    svg2pdf basic-shapes.svg basic-shapes-out.pdf 0.5
    svg2png basic-shapes.svg basic-shapes-out.png 0.5
}

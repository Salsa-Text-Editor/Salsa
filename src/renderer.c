#include "renderer.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "log.h"

#define create_buffer() (printf("\033[?1049h"))
#define original_buffer() (printf("\033[?1049l"))

int last_widget_id = 1;

void get_terminal_size(int *width, int *height) {
  struct winsize w;
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
  *width = w.ws_col;
  *height = w.ws_row;
}

// creates a display
Display create_display(int width, int height) {
  int size = width * height;
  Widget *widgets = calloc(1, sizeof(Widget));
  if (widgets == NULL) {
    Display err = {NULL, NULL, 0, 0, 0, 0};
    return err;
  }
  Cell *cells = calloc(size, sizeof(Cell));
  if (cells == NULL) {
    Display err = {NULL, NULL, 0, 0, 0, 0};
    return err;
  }
  Display display = {widgets, cells, 1, width, height, 1};
  return display;
}

Widget create_widget(int x1, int y1, int x2, int y2, int z_layer) {
  int size = (x2 - x1) * (y2 - y1);
  Cell *cells = calloc(size, sizeof(Cell));
  if (cells == NULL) {
    Widget err = {NULL, 0, 0, 0, 0, 0, 0, 0, 0};
    return err;
  }

  Widget widget = {cells, size, last_widget_id, x1, y1, x2, y2, z_layer, 1};
  last_widget_id++;
  return widget;
}

int resize_display(Display *display, int new_width, int new_height) {
  int size = new_width * new_height;
  Cell *cells = realloc(display->rendered_cells, size * sizeof(Cell));
  if (cells == NULL) {
    return 1;
  }
  display->width = new_width;
  display->height = new_height;
  display->rendered_cells = cells;
  return 0;
}

int resize_widget(Widget *widget, int new_x1, int new_y1, int new_x2,
                  int new_y2) {
  int size = (new_x2 - new_x1) * (new_y2 - new_y1);
  Cell *cells = realloc(widget->cells, size * sizeof(Cell));
  if (cells == NULL) {
    return 1;
  }
  widget->cells = cells;
  widget->x1 = new_x1;
  widget->y1 = new_y1;
  widget->x2 = new_x2;
  widget->y2 = new_y2;
  widget->size = size;
  return 0;
}

int set_cell(Widget *widget, int x, int y, Cell cell) {
  if (x < 0 || x >= widget->x2 - widget->x1 || y < 0 ||
      y >= widget->y2 - widget->y1) {
    return 1;
  }
  widget->cells[x + y * (widget->x2 - widget->x1)] = cell;
  return 0;
}

Cell get_cell(Widget widget, int x, int y) {
  if (x < 0 || x >= widget.x2 - widget.x1 || y < 0 ||
      y >= widget.y2 - widget.y1) {
    Cell err = {L'\0', {0, 0, 0}, {0, 0, 0}, 0};
    return err;
  }
  return widget.cells[x + y * (widget.x2 - widget.x1)];
}

// TODO: optimize later to use write()
int render_display(Display display) {
  reset_cursor();

  for (int i = 0; i < display.width * display.height; i++) {
    Cell cell = {L'\0', {0, 0, 0}, {0, 0, 0}, 0};
    display.rendered_cells[i] = cell;
  }

  for (int i = display.widget_count; i >= 0; i--) {
    Widget widget = display.widgets[i];
    for (int x = 0; x < widget.x2 - widget.x1; x++) {
      for (int y = 0; y < widget.y2 - widget.y1; y++) {
        if (display.rendered_cells[x + y * (display.width)].value == 0) {
          display.rendered_cells[x + y * (display.width)] =
              widget.cells[x + y * (widget.x2 - widget.x1)];
        }
      }
    }
  }

  for (int y = 0; y < display.height; y++) {
    for (int x = 0; x < display.width; x++) {
      if (display.rendered_cells[x + y * display.width].value == L'\0') {
        printf(" ");
        continue;
      }

      Cell cell = display.rendered_cells[x + y * display.width];

      printf(
          "\033[%s%s%s%s%s%s38;2;%d;%d;%d;48;2;%d;%d;%dm%lc\033[0m",
          ((cell.attributes & ATTRIBUTE_BOLD) == ATTRIBUTE_BOLD) ? "1;" : "",
          ((cell.attributes & ATTRIBUTE_ITALIC) == ATTRIBUTE_ITALIC) ? "3;"
                                                                     : "",
          ((cell.attributes & ATTRIBUTE_UNDERLINE) == ATTRIBUTE_UNDERLINE)
              ? "4;"
              : "",
          ((cell.attributes & ATTRIBUTE_BLINK) == ATTRIBUTE_BLINK) ? "5;" : "",
          ((cell.attributes & ATTRIBUTE_REVERSE) == ATTRIBUTE_REVERSE) ? "7;"
                                                                       : "",
          ((cell.attributes & ATTRIBUTE_STRIKE) == ATTRIBUTE_STRIKE) ? "9;"
                                                                     : "",
          cell.fg.r, cell.fg.g, cell.fg.b, cell.bg.r, cell.bg.g, cell.bg.b,
          cell.value);
    }
    if (y < display.height - 1) {
      printf("\n");
    }
  }
  fflush(stdout);

  return 0;
}

// inserts widget depending on z_layer, 0 is far left and it goes to the right
// for every number create new widget pointer that inserts the widget in the
// proper position returns 0 for success, returns 1 for any memory errors
int add_widget(Display *display, Widget widget) {
  Widget *new_widgets = malloc((display->widget_count + 1) * sizeof(Widget));
  if (new_widgets == NULL) {
    return 1;
  }

  int found = 0;
  int index = 0;
  for (int i = 0; i < display->widget_count; i++) {
    if ((display->widgets[i].z_layer == widget.z_layer ||
         i == display->widget_count - 1) &&
        !found) {
      found = 1;
      new_widgets[i] = widget;
      continue;
    } else {
      new_widgets[i] = display->widgets[index];
      index++;
    }
  }
  free(display->widgets);
  display->widgets = new_widgets;
  return 0;
}
// finds the widget and creates a new pointer that does not include the widget
// returns 0 for success, returns 1 for any memory errors, returns 2 if it does
// not exist
int remove_widget(Display *display, Widget widget) {
  Widget *new_widgets = malloc((display->widget_count - 1) * sizeof(Widget));
  if (new_widgets == NULL) {
    return 1;
  }

  int found = 0;
  int index = 0;
  for (int i = 0; i < display->widget_count; i++) {
    if (display->widgets[i].id != widget.id) {
      new_widgets[index] = display->widgets[i];
      index++;
    } else {
      found = 1;
    }
  }

  if (found == 0) {
    free(new_widgets);
    new_widgets = NULL;
    return 2;
  }

  free(display->widgets);
  display->widgets = new_widgets;
  return 0;
}

int destroy_widget(Widget *widget) {
  free(widget->cells);
  widget->cells = NULL;
  last_widget_id--;
  return 0;
}

int destroy_display(Display *display) {
  free(display->widgets);
  display->widgets = NULL;
  free(display->rendered_cells);
  display->rendered_cells = NULL;
  return 0;
}

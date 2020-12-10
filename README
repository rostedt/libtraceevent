
The official repository is here:

  https://git.kernel.org/pub/scm/libs/libtrace/libtraceevent.git/


To build:

    make;
    sudo make install;

To build in a specific directory outside of the source directory:

    make O=/path/to/build; sudo make O=/path/to/build

  Note that the path needs to exist before building.

To set the install path (the expected final location):

    make prefix=/usr; sudo make O=/path/to/build

To install in a directory not for the local system (for use to move
to another machine):

    make DESTDIR=/path/to/dest/ install

  Note, if you have write permission to the DESTDIR, then there is
  no reason to use sudo or switch to root.

  Note, DESTDIR must end with '/', otherwise the files will be appended
  to the path, which will most likely have unwanted results.

Contributions:

  For questions about the use of the library, please send email to:

    linux-trace-users@vger.kernel.org

    Subscribe: http://vger.kernel.org/vger-lists.html#linux-trace-users
    Archives: https://lore.kernel.org/linux-trace-users/

  For contributions to development, please send patches to:

    linux-trace-devel@vger.kernel.org

    Subscribe: http://vger.kernel.org/vger-lists.html#linux-trace-devel
    Archives: https://lore.kernel.org/linux-trace-devel/

  Note, this project follows the style of submitting patches as described
  by the Linux kernel.

     https://www.kernel.org/doc/html/v5.4/process/submitting-patches.html

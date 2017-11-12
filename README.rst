swiftix
=======

*swiftix* is an easy-to-use Swift version manager for Ubuntu.

Installing
**********

::

  $ curl -L https://goo.gl/r3wPxq | sh

How to use
**********

::

  # Downloads the latest list of Swift releases.
  $ swiftix update
  # Lists all the available Swift versions.
  $ swiftix available
  # Downloads the desired Swift version.
  $ swiftix install 4.0
  # Same as above, but downloads a snapshot.
  $ swiftix install 4.1 2017-11-06
  # Set the given Swift version to become the active one.
  $ swiftix activate 4.0
  # Remove the given Swift version.
  $ swiftix remove 4.0
  # List all the installed Swift versions.
  $ swiftix list

# Force install version 1.0.6 stable branch
# fix runtime dependencies

SRCREV = "f6dbce36181c44d0d08b6f4ca166508542875ce1"

RDEPENDS:${PN} += "${PYTHON_PN}-json ${PYTHON_PN}-dotenv ${PYTHON_PN}-logging ${PYTHON_PN}-unixadmin"

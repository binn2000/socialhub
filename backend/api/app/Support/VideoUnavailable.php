<?php

namespace App\Support;

use RuntimeException;

/** YouTube could not be reached, refused the key (or its daily quota is used up) or is not configured. */
class VideoUnavailable extends RuntimeException {}

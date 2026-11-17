<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LineSong extends Model
{
    protected $fillable = ['line_id', 'song_id', 'position', 'key'];

    public function song(): BelongsTo
    {
        return $this->belongsTo(Song::class);
    }
}

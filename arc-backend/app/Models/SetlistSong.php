<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SetlistSong extends Model
{
    use HasFactory;

    protected $fillable = ['setlist_id', 'song_id', 'position', 'key', 'section', 'line_id'];

    public function setlist(): BelongsTo
    {
        return $this->belongsTo(Setlist::class);
    }

    /** The line it came from, when it was brought in with one. */
    public function line(): BelongsTo
    {
        return $this->belongsTo(Line::class);
    }

    public function song(): BelongsTo
    {
        return $this->belongsTo(Song::class);
    }
}

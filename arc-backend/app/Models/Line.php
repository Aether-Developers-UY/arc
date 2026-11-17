<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Songs from the library played back to back, in the line's key; a song
 * keeps a key of its own when the line goes up a step there.
 */
class Line extends Model
{
    protected $fillable = ['name', 'key', 'created_by'];

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class);
    }

    public function lineSongs(): HasMany
    {
        return $this->hasMany(LineSong::class)->orderBy('position');
    }
}

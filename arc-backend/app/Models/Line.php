<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Songs from the library played back to back, each in its own key. */
class Line extends Model
{
    protected $fillable = ['name', 'created_by'];

    public function lineSongs(): HasMany
    {
        return $this->hasMany(LineSong::class)->orderBy('position');
    }
}

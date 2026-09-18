<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Setlist extends Model
{
    use HasFactory;

    protected $fillable = ['service_date', 'name', 'created_by'];

    protected function casts(): array
    {
        return ['service_date' => 'date:Y-m-d'];
    }

    public function setlistSongs(): HasMany
    {
        return $this->hasMany(SetlistSong::class)->orderBy('position');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

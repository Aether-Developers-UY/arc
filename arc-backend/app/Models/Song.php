<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Song extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'artist',
        'original_key',
        'tempo',
        'time_signature',
        'content',
        'notes',
        'created_by',
    ];

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

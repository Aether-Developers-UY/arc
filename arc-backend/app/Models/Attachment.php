<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Attachment extends Model
{
    use HasFactory;

    protected $fillable = [
        'song_id',
        'type',
        'original_name',
        'file_path',
        'mime_type',
        'size',
    ];

    public function song(): BelongsTo
    {
        return $this->belongsTo(Song::class);
    }
}

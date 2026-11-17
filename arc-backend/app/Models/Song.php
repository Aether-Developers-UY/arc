<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

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

    /** The search copy of the lyrics stays on the server. */
    protected $hidden = ['lyrics'];

    protected static function booted(): void
    {
        static::saving(function (Song $song) {
            if ($song->isDirty('content') || $song->lyrics === null) {
                $song->lyrics = self::searchableLyrics((string) $song->content);
            }
        });
    }

    /**
     * The lyrics as one line of plain words: no chords, no {directives},
     * lowercase and without accents, lines joined by a space so a phrase
     * that wraps onto the next line is still found.
     */
    public static function searchableLyrics(string $content): string
    {
        $lines = [];
        foreach (preg_split('/\R/u', $content) as $line) {
            if (preg_match('/^\s*\{.*\}\s*$/u', $line)) {
                continue;
            }
            $lines[] = preg_replace('/\[[^\]]*\]/u', '', $line);
        }

        return self::normalizeForSearch(implode(' ', $lines));
    }

    /** Lowercase, without accents and with single spaces. */
    public static function normalizeForSearch(string $text): string
    {
        $text = Str::lower(Str::ascii($text));

        return trim(preg_replace('/\s+/', ' ', $text));
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

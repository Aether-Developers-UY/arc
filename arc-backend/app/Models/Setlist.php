<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Setlist extends Model
{
    use HasFactory;

    protected $fillable = ['service_date', 'name', 'created_by', 'annex_id'];

    /** The blocks of a service, in the order they are played. */
    public const SECTIONS = ['inicio', 'linea', 'ofrenda', 'santa_cena'];

    /** What a setlist carries for each of its songs when it is shown. */
    public const SONGS_WITH = ['setlistSongs.song', 'setlistSongs.line:id,name'];

    /**
     * Renumbers the songs 0..n in service order: by block first (songs from
     * before the blocks go last), then by their current position. Keeps the
     * flat order that stage mode and sharing read the same as the blocks.
     */
    public function normalizePositions(): void
    {
        $rank = fn (SetlistSong $s) => $s->section === null
            ? count(self::SECTIONS)
            : array_search($s->section, self::SECTIONS, true);

        $this->setlistSongs()->get()
            ->sort(fn ($a, $b) => [$rank($a), $a->position, $a->id] <=> [$rank($b), $b->position, $b->id])
            ->values()
            ->each(function (SetlistSong $song, int $position) {
                if ($song->position !== $position) {
                    $song->update(['position' => $position]);
                }
            });
    }

    protected function casts(): array
    {
        return ['service_date' => 'date:Y-m-d'];
    }

    public function setlistSongs(): HasMany
    {
        return $this->hasMany(SetlistSong::class)->orderBy('position');
    }

    public function annex(): BelongsTo
    {
        return $this->belongsTo(Annex::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

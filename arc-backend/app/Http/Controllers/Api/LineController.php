<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LineRequest;
use App\Models\Line;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/** The library of lines, shared by everyone like the song library. */
class LineController extends Controller
{
    private const WITH = ['lineSongs.song:id,title,artist,original_key', 'attachments'];

    public function index()
    {
        $lines = Line::query()->with(self::WITH)->orderBy('name')->get();

        return response()->json(['data' => $lines]);
    }

    public function show(Line $line)
    {
        return response()->json(['data' => $line->load(self::WITH)]);
    }

    public function store(LineRequest $request)
    {
        $line = DB::transaction(function () use ($request) {
            $line = Line::create([
                'name' => $request->validated('name'),
                'key' => $request->validated('key'),
                'created_by' => $request->user()->id,
            ]);
            $this->saveSongs($line, $request->validated('songs'));

            return $line;
        });

        return response()->json(['data' => $line->load(self::WITH)], 201);
    }

    public function update(LineRequest $request, Line $line)
    {
        DB::transaction(function () use ($request, $line) {
            $line->update($request->safe()->only(['name', 'key']));
            $line->lineSongs()->delete();
            $this->saveSongs($line, $request->validated('songs'));
        });

        return response()->json(['data' => $line->fresh()->load(self::WITH)]);
    }

    public function destroy(Line $line)
    {
        // The rows cascade; the stored files have to go by hand.
        Storage::disk('public')->delete($line->attachments()->pluck('file_path')->all());
        $line->delete();

        return response()->noContent();
    }

    /** Each song in the given order, in its own key or the line's. */
    private function saveSongs(Line $line, array $songs): void
    {
        foreach (array_values($songs) as $position => $song) {
            $line->lineSongs()->create([
                'song_id' => $song['song_id'],
                'position' => $position,
                'key' => $song['key'] ?? $line->key,
            ]);
        }
    }
}

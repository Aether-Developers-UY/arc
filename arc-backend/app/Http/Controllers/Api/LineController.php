<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LineRequest;
use App\Models\Line;
use Illuminate\Support\Facades\DB;

/** The library of lines, shared by everyone like the song library. */
class LineController extends Controller
{
    private const SONG_FIELDS = 'lineSongs.song:id,title,artist,original_key';

    public function index()
    {
        $lines = Line::query()->with(self::SONG_FIELDS)->orderBy('name')->get();

        return response()->json(['data' => $lines]);
    }

    public function show(Line $line)
    {
        return response()->json(['data' => $line->load(self::SONG_FIELDS)]);
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

        return response()->json(['data' => $line->load(self::SONG_FIELDS)], 201);
    }

    public function update(LineRequest $request, Line $line)
    {
        DB::transaction(function () use ($request, $line) {
            $line->update($request->safe()->only(['name', 'key']));
            $line->lineSongs()->delete();
            $this->saveSongs($line, $request->validated('songs'));
        });

        return response()->json(['data' => $line->fresh()->load(self::SONG_FIELDS)]);
    }

    public function destroy(Line $line)
    {
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

<?php

use App\Models\Song;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A plain copy of each song's lyrics, without chords or section
     * markers, lowercase and without accents, so a phrase can be searched
     * even when chords sit in the middle of it.
     */
    public function up(): void
    {
        Schema::table('songs', function (Blueprint $table) {
            $table->longText('lyrics')->nullable()->after('content');
        });

        DB::table('songs')->select('id', 'content')->orderBy('id')->each(function ($song) {
            DB::table('songs')->where('id', $song->id)->update([
                'lyrics' => Song::searchableLyrics($song->content),
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('songs', function (Blueprint $table) {
            $table->dropColumn('lyrics');
        });
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Lines: songs from the library played back to back, kept in a library
     * of their own so a setlist can take a whole line at once. A setlist
     * song now also says which block of the service it belongs to.
     */
    public function up(): void
    {
        Schema::create('lines', function (Blueprint $table) {
            $table->engine = 'InnoDB';
            $table->id();
            $table->string('name', 120);
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
        });

        Schema::create('line_songs', function (Blueprint $table) {
            $table->engine = 'InnoDB';
            $table->id();
            $table->foreignId('line_id')->constrained('lines')->cascadeOnDelete();
            $table->foreignId('song_id')->constrained('songs')->cascadeOnDelete();
            $table->unsignedInteger('position');
            $table->string('key', 8);
            $table->timestamps();
        });

        Schema::table('setlist_songs', function (Blueprint $table) {
            // inicio, linea, ofrenda, santa_cena; null for songs added
            // before the blocks existed.
            $table->string('section', 20)->nullable()->after('key');
            $table->foreignId('line_id')->nullable()->after('section')->constrained('lines')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('setlist_songs', function (Blueprint $table) {
            $table->dropConstrainedForeignId('line_id');
            $table->dropColumn('section');
        });
        Schema::dropIfExists('line_songs');
        Schema::dropIfExists('lines');
    }
};

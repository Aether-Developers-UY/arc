<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('setlist_songs', function (Blueprint $table) {
            $table->engine = 'InnoDB';
            $table->id();
            $table->foreignId('setlist_id')->constrained('setlists')->cascadeOnDelete();
            $table->foreignId('song_id')->constrained('songs')->cascadeOnDelete();
            $table->unsignedInteger('position');
            $table->string('key', 8);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('setlist_songs');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A line is played in one key; its songs follow it unless one of them
     * goes up a step. Lines made before take the key of their first song.
     */
    public function up(): void
    {
        Schema::table('lines', function (Blueprint $table) {
            $table->string('key', 8)->nullable()->after('name');
        });

        DB::table('lines')->orderBy('id')->each(function ($line) {
            $first = DB::table('line_songs')->where('line_id', $line->id)->orderBy('position')->value('key');
            DB::table('lines')->where('id', $line->id)->update(['key' => $first ?? 'C']);
        });
    }

    public function down(): void
    {
        Schema::table('lines', function (Blueprint $table) {
            $table->dropColumn('key');
        });
    }
};

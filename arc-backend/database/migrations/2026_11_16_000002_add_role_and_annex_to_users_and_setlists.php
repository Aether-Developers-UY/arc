<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('standard')->after('email');
        });

        // Deleting a user must not take the church's songs and setlists with it.
        foreach (['songs', 'setlists'] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->dropForeign(['created_by']);
            });
            Schema::table($tableName, function (Blueprint $table) {
                $table->unsignedBigInteger('created_by')->nullable()->change();
                $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
            });
        }

        Schema::table('setlists', function (Blueprint $table) {
            $table->foreignId('annex_id')->nullable()->after('id')
                ->constrained('annexes')->restrictOnDelete();
        });

        $this->moveExistingDataToMainAnnex();

        Schema::table('setlists', function (Blueprint $table) {
            $table->unsignedBigInteger('annex_id')->nullable(false)->change();
        });
    }

    /**
     * Everything that exists before anexos goes into "Anexo principal", with
     * every user as a member, and the oldest user becomes the first admin.
     */
    private function moveExistingDataToMainAnnex(): void
    {
        $hasUsers = DB::table('users')->exists();
        if (! $hasUsers && ! DB::table('setlists')->exists()) {
            return;
        }

        $now = now();
        $annexId = DB::table('annexes')->insertGetId([
            'name' => 'Anexo principal',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('setlists')->update(['annex_id' => $annexId]);

        $userIds = DB::table('users')->orderBy('id')->pluck('id');
        DB::table('annex_user')->insert($userIds->map(fn ($userId) => [
            'annex_id' => $annexId,
            'user_id' => $userId,
            'created_at' => $now,
            'updated_at' => $now,
        ])->all());

        if ($hasUsers) {
            DB::table('users')->where('id', $userIds->first())->update(['role' => 'admin']);
        }
    }

    public function down(): void
    {
        Schema::table('setlists', function (Blueprint $table) {
            $table->dropConstrainedForeignId('annex_id');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('role');
        });

        foreach (['songs', 'setlists'] as $tableName) {
            Schema::table($tableName, function (Blueprint $table) {
                $table->dropForeign(['created_by']);
            });
            Schema::table($tableName, function (Blueprint $table) {
                $table->foreign('created_by')->references('id')->on('users')->cascadeOnDelete();
            });
        }

        DB::table('annex_user')->delete();
        DB::table('annexes')->delete();
    }
};

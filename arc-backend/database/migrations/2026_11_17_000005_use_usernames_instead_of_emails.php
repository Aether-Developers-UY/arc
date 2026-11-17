<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * People sign in with a username and a password; no email. Existing
     * users get the part of their email before the @ (made unique).
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username', 30)->nullable()->after('name');
        });

        $taken = [];
        foreach (DB::table('users')->orderBy('id')->get(['id', 'email']) as $user) {
            $base = Str::of(Str::before((string) $user->email, '@'))->ascii()->lower()
                ->replaceMatches('/[^a-z0-9._-]/', '')->limit(26, '')->toString();
            $base = strlen($base) >= 3 ? $base : 'usuario';
            $username = $base;
            for ($i = 2; in_array($username, $taken, true); $i++) {
                $username = $base.$i;
            }
            $taken[] = $username;
            DB::table('users')->where('id', $user->id)->update(['username' => $username]);
        }

        Schema::table('users', function (Blueprint $table) {
            $table->string('username', 30)->nullable(false)->unique()->change();
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['email']);
            $table->dropColumn(['email', 'email_verified_at']);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable()->unique()->after('name');
            $table->timestamp('email_verified_at')->nullable()->after('email');
        });
        DB::table('users')->update(['email' => DB::raw("CONCAT(username, '@arca.local')")]);
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
            $table->dropColumn('username');
        });
    }
};

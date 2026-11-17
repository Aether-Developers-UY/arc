<?php

namespace Database\Seeders;

use App\Models\Annex;
use Illuminate\Database\Seeder;

/**
 * The church's annexes. Safe to run again: the ones that exist stay as
 * they are.
 *
 *   php artisan db:seed --class=AnnexesSeeder
 */
class AnnexesSeeder extends Seeder
{
    public const NAMES = [
        'Anexo principal',
        'Burgues',
        'Civils y Alianza',
        'Casarino',
        'Rivera',
        'Ansina',
        'Barracas',
        'Mendoza',
    ];

    public function run(): void
    {
        foreach (self::NAMES as $name) {
            Annex::firstOrCreate(['name' => $name]);
        }
    }
}

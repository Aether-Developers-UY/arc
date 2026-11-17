<?php

namespace Tests\Feature;

use App\Models\Annex;
use Database\Seeders\AnnexesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AnnexesSeederTest extends TestCase
{
    use RefreshDatabase;

    private const ANNEXES = [
        'Anexo principal', 'Burgues', 'Civils y Alianza', 'Casarino', 'Rivera', 'Ansina', 'Barracas', 'Mendoza',
    ];

    public function test_it_creates_the_churchs_annexes(): void
    {
        $this->seed(AnnexesSeeder::class);

        $this->assertEqualsCanonicalizing(self::ANNEXES, Annex::pluck('name')->all());
    }

    public function test_running_it_again_does_not_duplicate_them(): void
    {
        $this->seed(AnnexesSeeder::class);
        $this->seed(AnnexesSeeder::class);

        $this->assertSame(count(self::ANNEXES), Annex::count());
    }

    public function test_the_default_seed_creates_them_too(): void
    {
        config([
            'arca.first_users.admin_password' => 'x-admin',
            'arca.first_users.standard_password' => 'x-standard',
        ]);

        $this->seed();

        $this->assertSame(count(self::ANNEXES), Annex::count());
    }
}

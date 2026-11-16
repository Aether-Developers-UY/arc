<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'role'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function annexes(): BelongsToMany
    {
        return $this->belongsToMany(Annex::class)->withTimestamps();
    }

    /**
     * What the app knows about the signed-in user (login and /me).
     */
    public function toProfileArray(): array
    {
        return [
            ...$this->only(['id', 'name', 'email', 'role']),
            'annexes' => $this->annexes()->orderBy('annexes.id')->get(['annexes.id', 'annexes.name'])
                ->map(fn (Annex $annex) => $annex->only(['id', 'name']))
                ->all(),
        ];
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function isMemberOf(Annex|int $annex): bool
    {
        $annexId = $annex instanceof Annex ? $annex->id : $annex;

        return $this->annexes()->whereKey($annexId)->exists();
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    private const FIELDS = ['id', 'name', 'username', 'role'];

    public function index()
    {
        return response()->json([
            'data' => User::orderBy('name')->get(self::FIELDS),
        ]);
    }

    public function store(StoreUserRequest $request)
    {
        $user = User::create($request->validated());

        return response()->json(['data' => $user->only(self::FIELDS)], 201);
    }

    public function update(UpdateUserRequest $request, User $user)
    {
        $data = $request->validated();

        if (($data['role'] ?? 'admin') !== 'admin' && $this->isLastAdmin($user)) {
            return response()->json(['message' => 'No podés quitar el rol al último admin.'], 422);
        }

        $user->update($data);

        // A reset is how the admin locks someone out (lost phone, someone
        // who left): end every open session.
        if (isset($data['password'])) {
            $user->tokens()->delete();
        }

        return response()->json(['data' => $user->only(self::FIELDS)]);
    }

    public function destroy(Request $request, User $user)
    {
        if ($user->is($request->user())) {
            return response()->json(['message' => 'No podés borrarte a vos mismo.'], 422);
        }
        if ($this->isLastAdmin($user)) {
            return response()->json(['message' => 'No podés borrar al último admin.'], 422);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->noContent();
    }

    private function isLastAdmin(User $user): bool
    {
        return $user->isAdmin()
            && ! User::where('role', 'admin')->whereKeyNot($user->id)->exists();
    }
}

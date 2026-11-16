<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AnnexRequest;
use App\Models\Annex;
use Illuminate\Http\Request;

class AnnexController extends Controller
{
    public function index(Request $request)
    {
        $memberOf = $request->user()->annexes()->pluck('annexes.id');

        $annexes = Annex::orderBy('name')->get()->map(fn (Annex $annex) => [
            'id' => $annex->id,
            'name' => $annex->name,
            'is_member' => $memberOf->contains($annex->id),
        ]);

        return response()->json(['data' => $annexes]);
    }

    public function join(Request $request, Annex $annex)
    {
        $request->user()->annexes()->syncWithoutDetaching([$annex->id]);

        return response()->noContent();
    }

    public function leave(Request $request, Annex $annex)
    {
        $request->user()->annexes()->detach($annex->id);

        return response()->noContent();
    }

    public function store(AnnexRequest $request)
    {
        $annex = Annex::create($request->validated());

        return response()->json(['data' => $annex->only(['id', 'name'])], 201);
    }

    public function update(AnnexRequest $request, Annex $annex)
    {
        $annex->update($request->validated());

        return response()->json(['data' => $annex->only(['id', 'name'])]);
    }

    public function destroy(Annex $annex)
    {
        // Losing a congregation's services by accident would be worse than
        // the extra step of deleting them first.
        if ($annex->setlists()->exists()) {
            return response()->json(['message' => 'Este anexo tiene setlists; borralos antes.'], 422);
        }

        $annex->delete();

        return response()->noContent();
    }
}

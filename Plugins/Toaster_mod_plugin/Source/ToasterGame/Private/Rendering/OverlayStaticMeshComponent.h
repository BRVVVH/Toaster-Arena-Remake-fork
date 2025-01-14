#pragma once

#include "Components/StaticMeshComponent.h"
#include "OverlayStaticMeshComponent.generated.h"

UCLASS(Blueprintable, ClassGroup = (Rendering, Common), hidecategories = (Object, Activation, "Components|Activation"), ShowCategories = (Mobility), editinlinenew, meta = (BlueprintSpawnableComponent))
class UOverlayStaticMeshComponent : public UStaticMeshComponent
{
    GENERATED_BODY()

public:
    // Should the overlay material be automatically created into a dynamic material instance
    UPROPERTY(EditAnywhere)
    bool bAutoCreateDynamicOverlay = true;
    
    // The material to draw over top of the mesh
    UPROPERTY(EditAnywhere)
    UMaterialInterface* OverlayMaterial;

    // Dynamic material pointer
    UPROPERTY(Transient)
    UMaterialInstanceDynamic* OverlayMaterialDynamic = nullptr;

    // Overlay value is sent to dynamic material instance if created.
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float OverlayValue = 0.f;

    // Get the overlay material
    UFUNCTION(BlueprintCallable, Category = "Rendering")
    UMaterialInterface* GetOverlayMaterial() const;

    // Set the overlay material, will auto-create dynamic instance if enabled
    UFUNCTION(BlueprintCallable, Category = "Rendering")
    void SetOverlayMaterial(UMaterialInterface* InMaterial);

    void GetUsedMaterials(TArray<UMaterialInterface*>& OutMaterials, bool bGetDebugMaterials = false) const override;
    int32 GetOverlayMaterialIndex() const;
    UMaterialInterface* GetMaterial(int32 MaterialIndex) const override;

#if WITH_EDITOR
    virtual bool GetMaterialPropertyPath(int32 ElementIndex, UObject*& OutOwner, FString& OutPropertyPath, FProperty*& OutProperty) override;
#endif // WITH_EDITOR

    virtual FPrimitiveSceneProxy* CreateSceneProxy() override;


	void TickComponent(float DeltaTime, enum ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
    void SendRenderDynamicData_Concurrent();
protected:
    void CreateRenderState_Concurrent(FRegisterComponentContext* Context) override;

    void OnRegister() override;

};
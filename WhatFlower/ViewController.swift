//
//  ViewController.swift
//  WhatFlower
//
//  Created by Liam Schäpers on 25.01.20.
//  Copyright © 2020 Liam Schäpers. All rights reserved.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var flowerDescription: UITextView!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
        flowerDescription.text = "Scan a plant to start a search!"
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        //Actions to perform when the user finished taking a picture.
        if let userPickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            detect(image: convert_image(image: userPickedImage))
        }
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cameraPressed(_ sender: UIBarButtonItem) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func convert_image(image: UIImage) -> CIImage {
        //Converting the image from UIImage to a CoreML readable image type called 'CIImage'
        guard let ciimage = CIImage(image: image) else {
            fatalError("Could not convert UIImage to CIImage!")
        }
        return ciimage
    }
    
    func detect(image: CIImage) {
        //Hand over the image taken by the user to the ML model and making a prediction on it.
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Could not load the ML Model correctly!")
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError("Could not load classification obeservations!")
            }
            if let firstResult = results.first {
                self.requestInfo(flowerName: firstResult.identifier)
                self.navigationItem.title = firstResult.identifier
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }
    
    func requestInfo(flowerName: String) {
        //Checking if the flower name is 'thorn apple', this name throws erros while querying from Wikipedia
        //cause it redirects to a list of pages. To avoid this error we have to replace the flower name by its
        //biological name.
        var name = flowerName
        if flowerName == "thorn apple" {
            name = "Crataegus"
        }
        
        //Creating and reading from a JSON query and adding the gained informations to the corresponding views.
        let wikipediaURl = "https://en.wikipedia.org/w/api.php"
        let parameters : [String:String] = ["format" : "json", "action" : "query", "prop" : "extracts|pageimages", "exintro" : "", "explaintext" : "", "titles" : name, "redirects" : "1", "pithumbsize" : "500", "indexpageids" : ""]
        Alamofire.request(wikipediaURl, method: .get, parameters: parameters).responseJSON { (response) in
            if response.result.isSuccess {
                let flowerJSON: JSON = JSON(response.result.value!)
                let pageid = flowerJSON["query"]["pageids"][0].stringValue
                let flowerDescription = flowerJSON["query"]["pages"][pageid]["extract"].stringValue
                let flowerImageURL = flowerJSON["query"]["pages"][pageid]["thumbnail"]["source"].stringValue
                
                DispatchQueue.main.async {
                    self.imageView.sd_setImage(with: URL(string: flowerImageURL), completed: nil)
                    self.flowerDescription.text = flowerDescription
                }
            }
        }
    }
}
